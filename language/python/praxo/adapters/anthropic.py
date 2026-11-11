from __future__ import annotations

import asyncio
import json
from dataclasses import dataclass, field
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request as HTTPRequest
from urllib.request import urlopen

from ..errors import PraxoError
from ..model import (
    ROLE_ASSISTANT,
    ROLE_SYSTEM,
    ROLE_TOOL,
    TOOL_CHOICE_AUTO,
    TOOL_CHOICE_NONE,
    TOOL_CHOICE_REQUIRED,
    Message,
    Request,
    Response,
    ToolCall,
    Usage,
)

DEFAULT_BASE_URL = "https://api.anthropic.com"
DEFAULT_VERSION = "2023-06-01"
DEFAULT_MAX_TOKENS = 1024


@dataclass
class AnthropicConfig:
    api_key: str
    model: str
    base_url: str = DEFAULT_BASE_URL
    version: str = DEFAULT_VERSION
    max_tokens: int = DEFAULT_MAX_TOKENS
    timeout: float = 60.0
    headers: dict[str, str] = field(default_factory=dict)


class AnthropicModel:
    def __init__(self, config: AnthropicConfig) -> None:
        self.config = config

    async def generate(self, request: Request) -> Response:
        if not self.config.api_key:
            raise PraxoError("anthropic: API key is required")
        if not self.config.model:
            raise PraxoError("anthropic: model is required")
        payload = self._payload(request, stream=False)
        data = await asyncio.to_thread(self._post, payload)
        return self._parse_response(data)

    async def generate_stream(
        self, request: Request, on_delta: Callable[[str], Any]
    ) -> Response:
        if not self.config.api_key:
            raise PraxoError("anthropic: API key is required")
        if not self.config.model:
            raise PraxoError("anthropic: model is required")
        payload = self._payload(request, stream=True)
        return await asyncio.to_thread(self._post_stream, payload, on_delta)

    def _payload(self, request: Request, stream: bool) -> dict[str, Any]:
        system, messages = _build_messages(request.messages)
        payload: dict[str, Any] = {
            "model": request.model or self.config.model,
            "max_tokens": self.config.max_tokens,
            "messages": messages,
            "stream": stream,
        }
        if system:
            payload["system"] = system
        if request.tools:
            payload["tools"] = [
                {
                    "name": spec.name,
                    "description": spec.description,
                    "input_schema": spec.parameters
                    if spec.parameters is not None
                    else {"type": "object", "properties": {}},
                }
                for spec in request.tools
            ]
            choice = _tool_choice(request.tool_choice)
            if choice is not None:
                payload["tool_choice"] = choice
        if request.temperature:
            payload["temperature"] = request.temperature
        return payload

    def _post(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = json.dumps(payload).encode("utf-8")
        request = HTTPRequest(
            self._endpoint(),
            data=data,
            headers=self._headers(stream=False),
            method="POST",
        )
        try:
            with urlopen(request, timeout=self.config.timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise PraxoError(
                f"anthropic: HTTP {exc.code}: {body[:512]}"
            ) from exc
        except URLError as exc:
            raise PraxoError(f"anthropic: {exc.reason}") from exc

    def _post_stream(
        self,
        payload: dict[str, Any],
        on_delta: Callable[[str], Any],
    ) -> Response:
        data = json.dumps(payload).encode("utf-8")
        request = HTTPRequest(
            self._endpoint(),
            data=data,
            headers=self._headers(stream=True),
            method="POST",
        )
        content: list[str] = []
        blocks: dict[int, dict[str, Any]] = {}
        input_tokens = 0
        output_tokens = 0
        cached_tokens = 0
        stop_reason: str | None = None
        stopped = False
        try:
            with urlopen(request, timeout=self.config.timeout) as response:
                for raw_line in response:
                    line = raw_line.decode("utf-8").strip()
                    if not line.startswith("data:"):
                        continue
                    raw = line[5:].strip()
                    if not raw:
                        continue
                    event = json.loads(raw)
                    kind = event.get("type")
                    if kind == "message_start":
                        usage = (event.get("message") or {}).get("usage") or {}
                        input_tokens = int(usage.get("input_tokens", 0))
                        cached_tokens = int(
                            usage.get("cache_read_input_tokens", 0)
                        )
                    elif kind == "content_block_start":
                        index = int(event.get("index", 0))
                        block = event.get("content_block") or {}
                        blocks[index] = {
                            "type": block.get("type", ""),
                            "id": block.get("id", ""),
                            "name": block.get("name", ""),
                            "input": block.get("input") or {},
                            "arguments": "",
                        }
                        text = block.get("text")
                        if text:
                            content.append(text)
                            on_delta(text)
                    elif kind == "content_block_delta":
                        index = int(event.get("index", 0))
                        block = blocks.setdefault(
                            index,
                            {
                                "type": "",
                                "id": "",
                                "name": "",
                                "input": {},
                                "arguments": "",
                            },
                        )
                        delta = event.get("delta") or {}
                        if delta.get("type") == "text_delta":
                            text = delta.get("text") or ""
                            if text:
                                content.append(text)
                                on_delta(text)
                        elif delta.get("type") == "input_json_delta":
                            block["arguments"] += delta.get("partial_json") or ""
                    elif kind == "message_delta":
                        delta = event.get("delta") or {}
                        stop_reason = delta.get("stop_reason") or stop_reason
                        usage = event.get("usage") or {}
                        output_tokens = int(usage.get("output_tokens", 0))
                        if usage.get("input_tokens"):
                            input_tokens = int(usage["input_tokens"])
                    elif kind == "message_stop":
                        stopped = True
                        break
                    elif kind == "error":
                        error = event.get("error") or {}
                        raise PraxoError(
                            f"anthropic: {error.get('message', 'stream error')}"
                        )
        except HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise PraxoError(
                f"anthropic: HTTP {exc.code}: {body[:512]}"
            ) from exc
        except URLError as exc:
            raise PraxoError(f"anthropic: {exc.reason}") from exc
        if not stopped:
            raise PraxoError("anthropic: stream ended before completion")
        calls: list[ToolCall] = []
        for index in sorted(blocks):
            block = blocks[index]
            if block["type"] != "tool_use":
                continue
            arguments = block["input"]
            if block["arguments"]:
                try:
                    arguments = json.loads(block["arguments"])
                except ValueError as exc:
                    raise PraxoError(
                        f"anthropic: tool {block['name']} arguments: {exc}"
                    ) from exc
            if not isinstance(arguments, dict):
                arguments = {"content": arguments}
            calls.append(
                ToolCall(
                    id=block["id"] or f"call-{len(calls) + 1}",
                    name=block["name"],
                    arguments=arguments,
                )
            )
        return Response(
            message=Message(
                role=ROLE_ASSISTANT,
                content="".join(content),
                tool_calls=calls,
            ),
            usage=Usage(
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                cached_tokens=cached_tokens,
            ),
            finish_reason=stop_reason,
        )

    def _endpoint(self) -> str:
        return self.config.base_url.rstrip("/") + "/v1/messages"

    def _headers(self, stream: bool) -> dict[str, str]:
        headers = {
            "Content-Type": "application/json",
            "Accept": "text/event-stream" if stream else "application/json",
            "x-api-key": self.config.api_key,
            "anthropic-version": self.config.version or DEFAULT_VERSION,
        }
        headers.update(self.config.headers)
        return headers

    def _parse_response(self, data: dict[str, Any]) -> Response:
        error = data.get("error")
        if error:
            raise PraxoError(f"anthropic: {error.get('message', error)}")
        content, calls = _parse_content(data.get("content") or [])
        usage = data.get("usage") or {}
        return Response(
            message=Message(
                role=ROLE_ASSISTANT,
                content=content,
                tool_calls=calls,
            ),
            usage=Usage(
                input_tokens=int(usage.get("input_tokens", 0)),
                output_tokens=int(usage.get("output_tokens", 0)),
                cached_tokens=int(usage.get("cache_read_input_tokens", 0)),
            ),
            finish_reason=data.get("stop_reason"),
        )


def _build_messages(messages: list[Message]) -> tuple[str, list[dict[str, Any]]]:
    system: list[str] = []
    out: list[dict[str, Any]] = []
    tool_results: list[dict[str, Any]] = []

    def flush() -> None:
        if tool_results:
            out.append({"role": "user", "content": list(tool_results)})
            tool_results.clear()

    for message in messages:
        if message.role == ROLE_SYSTEM:
            if message.content:
                system.append(message.content)
            continue
        if message.role == ROLE_TOOL:
            tool_results.append(
                {
                    "type": "tool_result",
                    "tool_use_id": message.tool_id or "",
                    "content": message.content,
                }
            )
            continue
        flush()
        content = _message_content(message)
        if content:
            out.append({"role": message.role, "content": content})
    flush()
    return "\n\n".join(system), out


def _message_content(message: Message) -> list[dict[str, Any]]:
    content: list[dict[str, Any]] = []
    if message.content:
        content.append({"type": "text", "text": message.content})
    for block in message.content_blocks:
        if block.type == "text" and block.text:
            content.append({"type": "text", "text": block.text})
    for call in message.tool_calls:
        content.append(
            {
                "type": "tool_use",
                "id": call.id,
                "name": call.name,
                "input": call.arguments,
            }
        )
    return content


def _tool_choice(choice: str | None) -> dict[str, str] | None:
    if choice == TOOL_CHOICE_AUTO:
        return {"type": "auto"}
    if choice == TOOL_CHOICE_REQUIRED:
        return {"type": "any"}
    if choice == TOOL_CHOICE_NONE:
        return {"type": "none"}
    return None


def _parse_content(
    blocks: list[dict[str, Any]],
) -> tuple[str, list[ToolCall]]:
    text: list[str] = []
    calls: list[ToolCall] = []
    for block in blocks:
        kind = block.get("type")
        if kind == "text":
            text.append(block.get("text") or "")
        elif kind == "tool_use":
            arguments = block.get("input") or {}
            if not isinstance(arguments, dict):
                arguments = {"content": arguments}
            calls.append(
                ToolCall(
                    id=block.get("id") or f"call-{len(calls) + 1}",
                    name=block.get("name") or "",
                    arguments=arguments,
                )
            )
    return "".join(text), calls
