from __future__ import annotations

import asyncio
import sys
import unittest
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.adapters.mcp import (
    MCPClient,
    MCPServerConfig,
    MCPToolAdapter,
    StdioTransport,
)
from praxo.errors import (
    MCPDuplicateToolError,
    MCPPaginationError,
    MCPTimeoutError,
    MCPToolError,
)
from praxo.tool import Registry

SERVER = Path(__file__).resolve().parent / "fake_mcp_server.py"


def server_config(mode: str = "default") -> MCPServerConfig:
    return MCPServerConfig(
        command=sys.executable,
        args=["-u", str(SERVER), "--mode", mode],
    )


class RecordingTransport:
    def __init__(self) -> None:
        self.sent: list[dict[str, Any]] = []
        self.incoming: asyncio.Queue[dict[str, Any] | None] = (
            asyncio.Queue()
        )
        self.started = False
        self.closed = False
        self.slow_started = asyncio.Event()

    async def start(self) -> None:
        self.started = True

    async def send(self, message: dict[str, Any]) -> None:
        self.sent.append(message)
        method = message.get("method")
        if method == "initialize":
            await self.incoming.put(
                {
                    "jsonrpc": "2.0",
                    "id": message["id"],
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {
                            "name": "recording",
                            "version": "1.0.0",
                        },
                    },
                }
            )
        elif method == "tools/call":
            name = (message.get("params") or {}).get("name")
            if name == "slow":
                self.slow_started.set()
                return
            await self.incoming.put(
                {
                    "jsonrpc": "2.0",
                    "id": message["id"],
                    "result": {
                        "content": [{"type": "text", "text": "ok"}],
                        "isError": False,
                    },
                }
            )

    async def receive(self) -> dict[str, Any] | None:
        return await self.incoming.get()

    async def close(self) -> None:
        self.closed = True
        await self.incoming.put(None)


class MCPClientTest(unittest.IsolatedAsyncioTestCase):
    async def test_handshake_pagination_and_schema_preservation(self) -> None:
        client = MCPClient(server_config(), timeout=5.0)
        async with client:
            self.assertTrue(client.connected)
            self.assertEqual(client.protocol_version, "2024-11-05")
            self.assertEqual(client.server_info["name"], "fake-mcp")
            tools = await client.list_tools()
        self.assertEqual(
            [tool.name for tool in tools],
            ["add", "echo", "fail", "multi"],
        )
        echo = next(tool for tool in tools if tool.name == "echo")
        self.assertEqual(echo.description, "Echo input")
        self.assertEqual(
            echo.input_schema,
            {
                "type": "object",
                "properties": {"text": {"type": "string"}},
                "required": ["text"],
            },
        )
        self.assertEqual(echo.to_spec().parameters, echo.input_schema)

    async def test_repeated_cursor_is_rejected(self) -> None:
        async with MCPClient(
            server_config("repeated-cursor"),
            timeout=5.0,
        ) as client:
            with self.assertRaises(MCPPaginationError) as raised:
                await client.list_tools()
        self.assertEqual(raised.exception.code, "MCP_PAGINATION")

    async def test_duplicate_tool_name_is_rejected(self) -> None:
        async with MCPClient(
            server_config("duplicate-name"),
            timeout=5.0,
        ) as client:
            with self.assertRaises(MCPDuplicateToolError) as raised:
                await client.list_tools()
        self.assertEqual(raised.exception.code, "MCP_DUPLICATE_TOOL")

    async def test_call_tool_maps_content_and_errors(self) -> None:
        async with MCPClient(server_config(), timeout=5.0) as client:
            self.assertEqual(
                await client.call_tool("echo", {"text": "hello"}),
                "hello",
            )
            self.assertEqual(
                await client.call_tool("add", {"a": 1, "b": 2}),
                {"sum": 3},
            )
            self.assertEqual(
                await client.call_tool("multi"),
                ["one", "two"],
            )
            with self.assertRaises(MCPToolError) as raised:
                await client.call_tool("fail")
        self.assertEqual(raised.exception.code, "MCP_TOOL_ERROR")
        self.assertIn("boom", str(raised.exception))

    async def test_register_tools_uses_registry_seam(self) -> None:
        async with MCPClient(server_config(), timeout=5.0) as client:
            registry = Registry()
            adapters = await client.register_tools(registry)
            self.assertEqual(
                [adapter.name for adapter in adapters],
                ["add", "echo", "fail", "multi"],
            )
            tool = registry.get("echo")
            self.assertIsInstance(tool, MCPToolAdapter)
            self.assertEqual(
                tool.parameters["properties"]["text"],
                {"type": "string"},
            )
            self.assertEqual(
                await tool.invoke({"text": "registered"}),
                "registered",
            )

    async def test_timeout_sends_cancellation_notification(self) -> None:
        transport = RecordingTransport()
        client = MCPClient(transport=transport, timeout=5.0)
        await client.connect()
        with self.assertRaises(MCPTimeoutError) as raised:
            await client.call_tool("slow", {}, timeout=0.05)
        await client.close()
        self.assertEqual(raised.exception.code, "MCP_TIMEOUT")
        cancelled = [
            message
            for message in transport.sent
            if message.get("method") == "notifications/cancelled"
        ]
        self.assertEqual(len(cancelled), 1)
        self.assertEqual(cancelled[0]["params"]["reason"], "timeout")
        self.assertTrue(transport.closed)

    async def test_cancelled_call_sends_notification(self) -> None:
        transport = RecordingTransport()
        async with MCPClient(transport=transport, timeout=5.0) as client:
            task = asyncio.create_task(client.call_tool("slow", {}))
            await asyncio.wait_for(
                transport.slow_started.wait(),
                timeout=1.0,
            )
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
            cancelled = [
                message
                for message in transport.sent
                if message.get("method") == "notifications/cancelled"
            ]
            self.assertEqual(len(cancelled), 1)
            self.assertEqual(
                cancelled[0]["params"]["reason"],
                "cancelled",
            )

    async def test_stdio_process_is_cleaned_up(self) -> None:
        transport = StdioTransport(server_config())
        client = MCPClient(transport=transport, timeout=5.0)
        await client.connect()
        process = transport.process
        self.assertIsNotNone(process)
        self.assertIsNone(process.returncode)
        await client.close()
        self.assertIsNotNone(transport.process.returncode)


if __name__ == "__main__":
    unittest.main()
