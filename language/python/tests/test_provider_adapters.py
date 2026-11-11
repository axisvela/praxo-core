from __future__ import annotations

import json
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.adapters.anthropic import AnthropicConfig, AnthropicModel
from praxo.adapters.gemini import GeminiConfig, GeminiModel
from praxo.adapters.openaicompat import OpenAIConfig, PROVIDER_BASE_URLS
from praxo.errors import PraxoError
from praxo.model import Message, Request, ToolSpec

ANTHROPIC = {
    "id": "msg-1",
    "type": "message",
    "role": "assistant",
    "content": [
        {"type": "text", "text": "hello"},
        {
            "type": "tool_use",
            "id": "tool-1",
            "name": "echo",
            "input": {"text": "hi"},
        },
    ],
    "stop_reason": "end_turn",
    "usage": {
        "input_tokens": 3,
        "output_tokens": 4,
        "cache_read_input_tokens": 2,
    },
}

ANTHROPIC_STREAM = [
    {"type": "message_start", "message": {"usage": {"input_tokens": 3}}},
    {
        "type": "content_block_start",
        "index": 0,
        "content_block": {"type": "text", "text": ""},
    },
    {
        "type": "content_block_delta",
        "index": 0,
        "delta": {"type": "text_delta", "text": "he"},
    },
    {
        "type": "content_block_delta",
        "index": 0,
        "delta": {"type": "text_delta", "text": "llo"},
    },
    {
        "type": "content_block_start",
        "index": 1,
        "content_block": {
            "type": "tool_use",
            "id": "tool-1",
            "name": "echo",
            "input": {},
        },
    },
    {
        "type": "content_block_delta",
        "index": 1,
        "delta": {"type": "input_json_delta", "partial_json": '{"text":'},
    },
    {
        "type": "content_block_delta",
        "index": 1,
        "delta": {"type": "input_json_delta", "partial_json": '"hi"}'},
    },
    {
        "type": "message_delta",
        "delta": {"stop_reason": "end_turn"},
        "usage": {"output_tokens": 4},
    },
    {"type": "message_stop"},
]

GEMINI = {
    "candidates": [
        {
            "content": {
                "role": "model",
                "parts": [
                    {"text": "hello"},
                    {"functionCall": {"name": "echo", "args": {"text": "hi"}}},
                ],
            },
            "finishReason": "STOP",
        }
    ],
    "usageMetadata": {
        "promptTokenCount": 3,
        "candidatesTokenCount": 4,
        "cachedContentTokenCount": 2,
    },
}

GEMINI_STREAM = [
    {
        "candidates": [
            {"content": {"parts": [{"text": "he"}]}},
        ]
    },
    {
        "candidates": [
            {"content": {"parts": [{"text": "llo"}]}},
        ]
    },
    {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {"functionCall": {"name": "echo", "args": {"text": "hi"}}}
                    ]
                },
                "finishReason": "STOP",
            }
        ],
        "usageMetadata": {"promptTokenCount": 3, "candidatesTokenCount": 4},
    },
]


class Handler(BaseHTTPRequestHandler):
    anthropic_headers: dict[str, str] = {}
    anthropic_body: dict[str, Any] = {}
    gemini_headers: dict[str, str] = {}
    gemini_body: dict[str, Any] = {}

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length))
        if self.path.startswith("/v1/messages"):
            Handler.anthropic_headers = {
                key.lower(): value for key, value in self.headers.items()
            }
            Handler.anthropic_body = body
            if body.get("stream"):
                self._stream(ANTHROPIC_STREAM)
            else:
                self._json(ANTHROPIC)
            return
        Handler.gemini_headers = {
            key.lower(): value for key, value in self.headers.items()
        }
        Handler.gemini_body = body
        if ":streamGenerateContent" in self.path:
            self._stream(GEMINI_STREAM)
        else:
            self._json(GEMINI)

    def _json(self, payload: dict[str, Any]) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode())

    def _stream(self, events: list[dict[str, Any]]) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for event in events:
            self.wfile.write(f"data: {json.dumps(event)}\n\n".encode())

    def log_message(self, *args: object) -> None:
        return


class ProviderAdapterTest(unittest.IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(
            target=cls.server.serve_forever, daemon=True
        )
        cls.thread.start()
        host, port = cls.server.server_address
        cls.base_url = f"http://{host}:{port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def anthropic(self) -> AnthropicModel:
        return AnthropicModel(
            AnthropicConfig(
                api_key="ak",
                model="claude-test",
                base_url=self.base_url,
            )
        )

    def gemini(self) -> GeminiModel:
        return GeminiModel(
            GeminiConfig(
                api_key="gk",
                model="gemini-test",
                base_url=self.base_url,
            )
        )

    def request(self) -> Request:
        return Request(
            messages=[
                Message(role="system", content="be brief"),
                Message(role="user", content="hi"),
            ],
            tools=[ToolSpec(name="echo", description="Echo", parameters={"type": "object"})],
            tool_choice="auto",
            temperature=0.2,
        )

    async def test_anthropic_generate(self) -> None:
        response = await self.anthropic().generate(self.request())
        self.assertEqual(response.message.content, "hello")
        self.assertEqual(response.message.tool_calls[0].id, "tool-1")
        self.assertEqual(response.message.tool_calls[0].arguments, {"text": "hi"})
        self.assertEqual(response.usage.cached_tokens, 2)
        self.assertEqual(response.finish_reason, "end_turn")
        self.assertEqual(Handler.anthropic_headers["x-api-key"], "ak")
        self.assertEqual(Handler.anthropic_headers["anthropic-version"], "2023-06-01")
        self.assertEqual(Handler.anthropic_body["system"], "be brief")
        self.assertEqual(
            Handler.anthropic_body["tools"][0]["input_schema"], {"type": "object"}
        )
        self.assertEqual(Handler.anthropic_body["tool_choice"], {"type": "auto"})

    async def test_anthropic_stream(self) -> None:
        deltas: list[str] = []
        response = await self.anthropic().generate_stream(
            self.request(), deltas.append
        )
        self.assertEqual(deltas, ["he", "llo"])
        self.assertEqual(response.message.content, "hello")
        self.assertEqual(response.message.tool_calls[0].arguments, {"text": "hi"})
        self.assertEqual(response.usage.output_tokens, 4)

    async def test_gemini_generate(self) -> None:
        response = await self.gemini().generate(self.request())
        self.assertEqual(response.message.content, "hello")
        self.assertEqual(response.message.tool_calls[0].name, "echo")
        self.assertEqual(response.message.tool_calls[0].arguments, {"text": "hi"})
        self.assertEqual(response.usage.input_tokens, 3)
        self.assertEqual(response.finish_reason, "STOP")
        self.assertEqual(Handler.gemini_headers["x-goog-api-key"], "gk")
        self.assertEqual(
            Handler.gemini_body["system_instruction"],
            {"parts": [{"text": "be brief"}]},
        )
        self.assertEqual(
            Handler.gemini_body["toolConfig"]["functionCallingConfig"]["mode"],
            "AUTO",
        )

    async def test_gemini_stream(self) -> None:
        deltas: list[str] = []
        response = await self.gemini().generate_stream(
            self.request(), deltas.append
        )
        self.assertEqual(deltas, ["he", "llo"])
        self.assertEqual(response.message.tool_calls[0].arguments, {"text": "hi"})
        self.assertEqual(response.finish_reason, "STOP")

    async def test_requires_api_key(self) -> None:
        with self.assertRaisesRegex(PraxoError, "API key is required"):
            await AnthropicModel(
                AnthropicConfig(api_key="", model="m", base_url=self.base_url)
            ).generate(self.request())
        with self.assertRaisesRegex(PraxoError, "API key is required"):
            await GeminiModel(
                GeminiConfig(api_key="", model="m", base_url=self.base_url)
            ).generate(self.request())

    def test_provider_presets(self) -> None:
        self.assertEqual(
            OpenAIConfig.for_provider("deepseek", "deepseek-chat").base_url,
            PROVIDER_BASE_URLS["deepseek"],
        )
        self.assertEqual(
            OpenAIConfig.for_provider("kimi", "moonshot-v1-8k").base_url,
            PROVIDER_BASE_URLS["kimi"],
        )
        with self.assertRaises(ValueError):
            OpenAIConfig.for_provider("unknown", "model")
