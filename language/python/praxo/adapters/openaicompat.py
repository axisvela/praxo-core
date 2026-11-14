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
    Message,
    Request,
    Response,
    ToolCall,
    Usage,
)


PROVIDER_BASE_URLS = {
    "openai": "https://api.openai.com/v1",
    "deepseek": "https://api.deepseek.com/v1",
    "kimi": "https://api.moonshot.cn/v1",
    "moonshot": "https://api.moonshot.cn/v1",
    "openrouter": "https://openrouter.ai/api/v1",
    "groq": "https://api.groq.com/openai/v1",
    "together": "https://api.together.xyz/v1",
}


@dataclass
class OpenAIConfig:
    base_url: str
    api_key: str = ""
    model: str = ""
    timeout: float = 60.0
    headers: dict[str, str] = field(default_factory=dict)

    @classmethod
    def for_provider(
        cls,
        provider: str,
        model: str,
        api_key: str = "",
        **kwargs: Any,
    ) -> OpenAIConfig:
        key = provider.strip().lower()
        base_url = PROVIDER_BASE_URLS.get(key)
        if base_url is None:
            raise ValueError(f"unknown OpenAI-compatible provider: {provider}")
        return cls(
            base_url=base_url,
            api_key=api_key,
            model=model,
            **kwargs,
        )


class OpenAICompatibleModel:
    def __init__(self, config: OpenAIConfig) -> None:
        self.config = config

    async def generate(self, request: Request) -> Response:
        payload = self._payload(request, stream=False)
        data = await asyncio.to_thread(self._post, payload)
        return self._parse_response(data)

    async def generate_stream(
        self, request: Request, on_delta: Callable[[str], Any]
    ) -> Response:
        payload = self._payload(request, stream=True)
        return await asyncio.to_thread(self._post_stream, payload, on_delta)

    def _payload(self, request: Request, stream: bool) -> dict[str, Any]:
        messages = [_openai_message(message) for message in request.messages]
        payload: dict[str, Any] = {
            "model": request.model or self.config.model,
            "messages": messages,
            "stream": stream,
        }
        if request.tools:
            tools = []
            for spec in request.tools:
                function: dict[str, Any] = {
                    "name": spec.name,
                    "description": spec.description,
                }
                if spec.parameters is not None:
                    function["parameters"] = spec.parameters
                tools.append({"type": "function", "function": function})
            payload["tools"] = tools
        if request.tool_choice is not None:
            payload["tool_choice"] = request.tool_choice
        if request.response_format is not None:
            payload["response_format"] = {
                "type": "json_schema",
                "json_schema": {
                    "name": request.response_format.name or "output",
                    "schema": request.response_format.schema or {},
                },
            }
        if request.temperature:
            payload["temperature"] = request.temperature
        return payload

    def _post(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = json.dumps(payload).encode("utf-8")
        request = HTTPRequest(
            self._endpoint(),
            data=data,
            headers=self._headers(),
            method="POST",
        )
        try:
            with urlopen(request, timeout=self.config.timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise PraxoError(
                f"openaicompat: HTTP {exc.code}: {body[:512]}"
            ) from exc
        except URLError as exc:
            raise PraxoError(f"openaicompat: {exc.reason}") from exc

    def _post_stream(
        self,
        payload: dict[str, Any],
        on_delta: Callable[[str], Any],
    ) -> Response:
        data = json.dumps(payload).encode("utf-8")
        request = HTTPRequest(
            self._endpoint(),
            data=data,
            headers=self._headers(),
            method="POST",
        )
        content: list[str] = []
        calls: dict[int, dict[str, Any]] = {}
        usage = Usage()
        finish_reason: str | None = None
        done = False
        try:
            with urlopen(request, timeout=self.config.timeout) as response:
                for raw_line in response:
                    line = raw_line.decode("utf-8").strip()
                    if not line.startswith("data:"):
                        continue
                    chunk = line[5:].strip()
                    if chunk == "[DONE]":
                        done = True
                        break
                    if not chunk:
                        continue
                    event = json.loads(chunk)
                    if event.get("usage"):
                        usage = _parse_usage(event["usage"])
                    for choice in event.get("choices", []):
                        finish_reason = choice.get("finish_reason") or finish_reason
                        delta = choice.get("delta") or {}
                        text = delta.get("content")
                        if text:
                            content.append(text)
                            on_delta(text)
                        for call in delta.get("tool_calls") or []:
                            index = call.get("index", 0)
                            slot = calls.setdefault(
                                index,
                                {"id": "", "name": "", "arguments": ""},
                            )
                            if call.get("id"):
                                slot["id"] = call["id"]
                            function = call.get("function") or {}
                            if function.get("name"):
                                slot["name"] += function["name"]
                            if function.get("arguments"):
                                slot["arguments"] += function["arguments"]
        except HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise PraxoError(
                f"openaicompat: HTTP {exc.code}: {body[:512]}"
            ) from exc
        except URLError as exc:
            raise PraxoError(f"openaicompat: {exc.reason}") from exc
        if not done and finish_reason is None:
            raise PraxoError("openaicompat: stream ended before completion")
        tool_calls = [_build_call(index, value) for index, value in sorted(calls.items())]
        return Response(
            message=Message(
                role=ROLE_ASSISTANT,
                content="".join(content),
                tool_calls=tool_calls,
            ),
            usage=usage,
            finish_reason=finish_reason,
        )

    def _endpoint(self) -> str:
        return self.config.base_url.rstrip("/") + "/chat/completions"

    def _headers(self) -> dict[str, str]:
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        if self.config.api_key:
            headers["Authorization"] = f"Bearer {self.config.api_key}"
        headers.update(self.config.headers)
        return headers

    def _parse_response(self, data: dict[str, Any]) -> Response:
        choices = data.get("choices") or []
        if not choices:
            raise PraxoError("openaicompat: response has no choices")
        choice = choices[0]
        message = choice.get("message") or {}
        calls = [
            _build_call(index, call)
            for index, call in enumerate(message.get("tool_calls") or [])
        ]
        return Response(
            message=Message(
                role=ROLE_ASSISTANT,
                content=message.get("content") or "",
                tool_calls=calls,
            ),
            usage=_parse_usage(data.get("usage") or {}),
            finish_reason=choice.get("finish_reason"),
        )


def _openai_message(message: Message) -> dict[str, Any]:
    out: dict[str, Any] = {"role": message.role}
    content = _openai_content(message)
    if content is not None:
        out["content"] = content
    if message.tool_calls:
        calls = []
        for call in message.tool_calls:
            calls.append(
                {
                    "id": call.id,
                    "type": "function",
                    "function": {
                        "name": call.name,
                        "arguments": json.dumps(call.arguments),
                    },
                }
            )
        out["tool_calls"] = calls
    if message.tool_id is not None:
        out["tool_call_id"] = message.tool_id
    return out


def _openai_content(message: Message) -> Any:
    if not message.content_blocks:
        return message.content or None
    parts: list[dict[str, Any]] = []
    if message.content:
        parts.append({"type": "text", "text": message.content})
    for block in message.content_blocks:
        if block.type == "text":
            if not block.text:
                raise PraxoError("openaicompat: text content block is empty")
            parts.append({"type": "text", "text": block.text})
        elif block.type == "image_url":
            if not block.image_url:
                raise PraxoError("openaicompat: image_url content block is empty")
            parts.append(
                {"type": "image_url", "image_url": {"url": block.image_url}}
            )
        else:
            raise PraxoError(
                f"openaicompat: unsupported content block type {block.type!r}"
            )
    if not parts:
        return None
    if len(parts) == 1 and parts[0]["type"] == "text":
        return parts[0]["text"]
    return parts


def _build_call(index: int, raw: dict[str, Any]) -> ToolCall:
    function = raw.get("function")
    if function is None:
        function = {
            "name": raw.get("name", ""),
            "arguments": raw.get("arguments", "{}"),
        }
    arguments = function.get("arguments") or "{}"
    try:
        parsed = json.loads(arguments)
    except (ValueError, TypeError):
        parsed = {"content": arguments}
    if not isinstance(parsed, dict):
        parsed = {"content": parsed}
    return ToolCall(
        id=raw.get("id") or f"call-{index}",
        name=function.get("name", ""),
        arguments=parsed,
    )


def _parse_usage(raw: dict[str, Any]) -> Usage:
    details = raw.get("prompt_tokens_details") or {}
    return Usage(
        input_tokens=int(raw.get("prompt_tokens", 0)),
        output_tokens=int(raw.get("completion_tokens", 0)),
        cached_tokens=int(details.get("cached_tokens", 0)),
    )
