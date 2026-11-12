from __future__ import annotations

import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.adapters.mcp import MCPClient
from praxo.adapters.mcp_http import (
    StreamableHTTPConfig,
    StreamableHTTPTransport,
)
from praxo.errors import MCPTransportError


class FakeStreamableHTTP:
    def __init__(self) -> None:
        self.requests: list[dict[str, Any]] = []
        self.deleted = False
        self.sse_calls = False
        outer = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self) -> None:
                length = int(self.headers.get("Content-Length", "0"))
                message = json.loads(self.rfile.read(length))
                outer.requests.append(
                    {
                        "message": message,
                        "headers": {key.lower(): value for key, value in self.headers.items()},
                    }
                )
                method = message.get("method")
                if method == "initialize":
                    outer._json(
                        self,
                        200,
                        {
                            "jsonrpc": "2.0",
                            "id": message["id"],
                            "result": {
                                "protocolVersion": "2025-03-26",
                                "capabilities": {"tools": {}},
                                "serverInfo": {"name": "fake-http", "version": "1"},
                            },
                        },
                        {"Mcp-Session-Id": "sess-1"},
                    )
                elif method and method.startswith("notifications/"):
                    self.send_response(202)
                    self.end_headers()
                elif method == "tools/list":
                    outer._json(
                        self,
                        200,
                        {
                            "jsonrpc": "2.0",
                            "id": message["id"],
                            "result": {
                                "tools": [
                                    {
                                        "name": "echo",
                                        "description": "Echo input",
                                        "inputSchema": {
                                            "type": "object",
                                            "properties": {
                                                "text": {"type": "string"}
                                            },
                                            "required": ["text"],
                                        },
                                    }
                                ]
                            },
                        },
                    )
                elif method == "tools/call":
                    if outer.sse_calls:
                        outer._sse(
                            self,
                            {
                                "jsonrpc": "2.0",
                                "id": message["id"],
                                "result": {
                                    "content": [
                                        {"type": "text", "text": "sse-ok"}
                                    ]
                                },
                            },
                        )
                    else:
                        outer._json(
                            self,
                            200,
                            {
                                "jsonrpc": "2.0",
                                "id": message["id"],
                                "result": {
                                    "content": [
                                        {"type": "text", "text": "http-ok"}
                                    ]
                                },
                            },
                        )
                else:
                    outer._json(
                        self,
                        200,
                        {
                            "jsonrpc": "2.0",
                            "id": message.get("id"),
                            "result": {},
                        },
                    )

            def do_DELETE(self) -> None:
                outer.deleted = True
                self.send_response(200)
                self.end_headers()

            def log_message(self, *args: object) -> None:
                pass

        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(
            target=self.httpd.serve_forever,
            daemon=True,
        )
        self.thread.start()
        self.url = f"http://127.0.0.1:{self.httpd.server_port}/mcp"

    def close(self) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()

    def _json(
        self,
        handler: BaseHTTPRequestHandler,
        status: int,
        body: dict[str, Any],
        headers: dict[str, str] | None = None,
    ) -> None:
        payload = json.dumps(body).encode("utf-8")
        handler.send_response(status)
        handler.send_header("Content-Type", "application/json")
        handler.send_header("Content-Length", str(len(payload)))
        for key, value in (headers or {}).items():
            handler.send_header(key, value)
        handler.end_headers()
        handler.wfile.write(payload)

    def _sse(
        self,
        handler: BaseHTTPRequestHandler,
        body: dict[str, Any],
    ) -> None:
        payload = (
            "event: message\n"
            f"data: {json.dumps(body)}\n\n"
        ).encode("utf-8")
        handler.send_response(200)
        handler.send_header("Content-Type", "text/event-stream")
        handler.send_header("Content-Length", str(len(payload)))
        handler.end_headers()
        handler.wfile.write(payload)


class StreamableHTTPTransportTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.server = FakeStreamableHTTP()
        self.transport = StreamableHTTPTransport(
            StreamableHTTPConfig(self.server.url, timeout=5.0)
        )
        self.client = MCPClient(
            transport=self.transport,
            timeout=5.0,
            protocol_version="2025-03-26",
        )

    async def asyncTearDown(self) -> None:
        await self.client.close()
        self.server.close()

    async def test_handshake_list_call_and_close(self) -> None:
        async with self.client:
            self.assertEqual(self.client.protocol_version, "2025-03-26")
            self.assertEqual(self.transport.session_id, "sess-1")
            tools = await self.client.list_tools()
            self.assertEqual([tool.name for tool in tools], ["echo"])
            self.assertEqual(
                tools[0].input_schema["properties"]["text"]["type"],
                "string",
            )
            result = await self.client.call_tool("echo", {"text": "hi"})
            self.assertEqual(result, "http-ok")

        listed = next(
            item
            for item in self.server.requests
            if item["message"].get("method") == "tools/list"
        )
        self.assertEqual(listed["headers"]["mcp-session-id"], "sess-1")
        self.assertEqual(
            listed["headers"]["mcp-protocol-version"],
            "2025-03-26",
        )
        self.assertTrue(self.server.deleted)

    async def test_sse_response_is_parsed(self) -> None:
        self.server.sse_calls = True
        async with self.client:
            result = await self.client.call_tool("echo", {"text": "hi"})
        self.assertEqual(result, "sse-ok")

    async def test_remote_plain_http_is_rejected(self) -> None:
        transport = StreamableHTTPTransport(
            StreamableHTTPConfig("http://example.com/mcp")
        )
        with self.assertRaises(MCPTransportError):
            await transport.start()
