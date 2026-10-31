from __future__ import annotations

import json
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PraxoError
from praxo.model import Message, Request, Response, Usage

NON_STREAM = {
    "choices": [
        {
            "message": {
                "role": "assistant",
                "content": "hello",
                "tool_calls": [
                    {
                        "id": "c1",
                        "function": {
                            "name": "echo",
                            "arguments": '{"text":"hi"}',
                        },
                    }
                ],
            },
            "finish_reason": "stop",
        }
    ],
    "usage": {"prompt_tokens": 3, "completion_tokens": 4},
}

STREAM = [
    {"choices": [{"delta": {"role": "assistant", "content": "he"}}]},
    {"choices": [{"delta": {"content": "llo"}}]},
    {
        "choices": [
            {
                "delta": {
                    "tool_calls": [
                        {
                            "index": 0,
                            "id": "c1",
                            "function": {"name": "echo", "arguments": '{"text":'},
                        }
                    ]
                }
            }
        ]
    },
    {
        "choices": [
            {
                "delta": {
                    "tool_calls": [
                        {"index": 0, "function": {"arguments": '"hi"}'}}
                    ]
                }
            }
        ]
    },
    {"choices": [{"delta": {}, "finish_reason": "stop"}]},
    {"choices": [], "usage": {"prompt_tokens": 3, "completion_tokens": 4}},
]


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length))
        messages = body.get("messages") or []
        prompt = messages[-1].get("content") if messages else None
        self.send_response(200)
        if body.get("stream"):
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            if prompt == "truncate":
                self.wfile.write(
                    b'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n'
                )
                return
            if prompt == "half":
                self.wfile.write(b'data: {"choices":[{"delta":')
                return
            for chunk in STREAM:
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
            self.wfile.write(b"data: [DONE]\n\n")
            return
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(NON_STREAM).encode())

    def log_message(self, *args: object) -> None:
        return


class OpenAICompatTest(unittest.IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        host, port = cls.server.server_address
        cls.base_url = f"http://{host}:{port}/v1"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def model(self) -> OpenAICompatibleModel:
        return OpenAICompatibleModel(
            OpenAIConfig(base_url=self.base_url, api_key="k", model="test")
        )

    async def test_generate(self) -> None:
        response = await self.model().generate(
            Request(messages=[Message(role="user", content="hi")])
        )
        self.assertEqual(response.message.content, "hello")
        self.assertEqual(response.message.tool_calls[0].name, "echo")
        self.assertEqual(response.message.tool_calls[0].arguments, {"text": "hi"})
        self.assertEqual(response.usage.input_tokens, 3)
        self.assertEqual(response.usage.output_tokens, 4)

    async def test_generate_stream(self) -> None:
        deltas: list[str] = []
        response = await self.model().generate_stream(
            Request(messages=[Message(role="user", content="hi")]),
            deltas.append,
        )
        self.assertEqual(deltas, ["he", "llo"])
        self.assertEqual(response.message.content, "hello")
        self.assertEqual(response.message.tool_calls[0].arguments, {"text": "hi"})
        self.assertEqual(response.usage.output_tokens, 4)

    async def test_generate_stream_rejects_truncated_stream(self) -> None:
        with self.assertRaisesRegex(
            PraxoError, "stream ended before completion"
        ):
            await self.model().generate_stream(
                Request(messages=[Message(role="user", content="truncate")]),
                lambda delta: None,
            )

    async def test_generate_stream_rejects_half_packet(self) -> None:
        with self.assertRaises(json.JSONDecodeError):
            await self.model().generate_stream(
                Request(messages=[Message(role="user", content="half")]),
                lambda delta: None,
            )


class StreamingAgentTest(unittest.IsolatedAsyncioTestCase):
    async def test_agent_streams_deltas(self) -> None:
        class Model:
            async def generate(self, request: Request) -> Response:
                return Response(message=Message(role="assistant", content="hello"))

            async def generate_stream(self, request: Request, on_delta) -> Response:
                on_delta("he")
                on_delta("llo")
                return Response(
                    message=Message(role="assistant", content="hello"),
                    usage=Usage(output_tokens=2),
                )

        deltas: list[str] = []
        agent = Agent(
            AgentOptions(model=Model(), on_delta=deltas.append)
        )
        result = await agent.run(Session(id="s1"), "hi")
        self.assertEqual(result.output, "hello")
        self.assertEqual(deltas, ["he", "llo"])

    async def test_stream_callback_failure_aborts_run(self) -> None:
        class Model:
            async def generate(self, request: Request) -> Response:
                return Response(message=Message(role="assistant", content="done"))

            async def generate_stream(self, request: Request, on_delta) -> Response:
                on_delta("he")
                return Response(
                    message=Message(role="assistant", content="done")
                )

        def fail(delta: str) -> None:
            raise RuntimeError("stream down")

        agent = Agent(AgentOptions(model=Model(), on_delta=fail))
        with self.assertRaisesRegex(RuntimeError, "stream down"):
            await agent.run(Session(id="s1"), "hi")


if __name__ == "__main__":
    unittest.main()
