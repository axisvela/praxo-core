from __future__ import annotations

import asyncio
import json
from dataclasses import dataclass, field
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request as HTTPRequest
from urllib.request import urlopen

from ..errors import PraxoError
from ..model import (
    ROLE_ASSISTANT,
    ROLE_SYSTEM,
    ROLE_TOOL,
    TOOL_CHOICE_NONE,
    TOOL_CHOICE_REQUIRED,
    Message,
    Request,
    Response,
    ToolCall,
    Usage,
)

DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com"


@dataclass
class GeminiConfig:
    api_key: str
    model: str
    base_url: str = DEFAULT_BASE_URL
    max_output_tokens: int = 0
    timeout: float = 60.0
    headers: dict[str, str] = field(default_factory=dict)


class GeminiModel:
    def __init__(self, config: GeminiConfig) -> None:
        self.config = config

    async def generate(self, request: Request) -> Response:
        if not self.config.api_key:
            raise PraxoError("gemini: API key is required")
        if not self.config.model:
            raise PraxoError("gemini: model is required")
        payload = self._payload(request)
        data = await asyncio.to_thread(self._post, payload, False)
        return self._parse_response(data)

    async def generate_stream(
        self, request: Request, on_delta: Callable[[str], Any]
    ) -> Response:
        if not self.config.api_key:
            raise PraxoError("gemini: API key is required")
        if not self.config.model:
            raise PraxoError("gemini: model is required")
        payload = self._payload(request)
        return await asyncio.to_thread(self._post_stream, payload, on_delta)

    def _payload(self, request: Request) -> dict[str, Any]:
        system, contents = _build_contents(request.messages)
        payload: dict[str, Any] = {"contents": contents}
        if system:
            payload["system_instruction"] = system
        if request.tools:
            payload["tools"] = [
                {
                    "functionDeclarations": [
                        {
                            "name": spec.name,
                            "description": spec.description,
                            "parameters": spec.parameters
                            if spec.parameters is not None
                            else {"type": "object", "properties": {}},
                        }
                        for spec in request.tools
                    ]
                }
            ]
            payload["toolConfig"] = {
                "functionCallingConfig": {
                    "mode": _tool_mode(request.tool_choice)
                }
            }
        if request.temperature or self.config.max_output_tokens:
            payload["generationConfig"] = {
                "temperature": request.temperature,
                "maxOutputTokens": self.config.max_output_tokens,
            }
        return payload

    def _post(self, payload: dict[str, Any], stream: bool) -> dict[str, Any]:
        request = HTTPRequest(
            self._endpoint(stream),
            data=json.dumps(payload).encode("utf-8"),
            headers=self._headers(stream),
            method="POST",
        )
        try:
            with urlopen(request, timeout=self.config.timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise PraxoError(
                f"gemini: HTTP {exc.code}: {body[:512]}"
            ) from exc
        except URLError as exc:
            raise PraxoError(f"gemini: {exc.reason}") from exc

    def _post_stream(
        self,
        payload: dict[str, Any],
        on_delta: Callable[[str], Any],
    ) -> Response:
        request = HTTPRequest(
            self._endpoint(True),
            data=json.dumps(payload).encode("utf-8"),
            headers=self._headers(True),
            method="POST",
        )
        content: list[str] = []
        calls: list[ToolCall] = []
        usage = Usage()
        finish_reason: str | None = None
        try:
            with urlopen(request, timeout=self.config.timeout) as response:
                for raw_line in response:
                    line = raw_line.decode("utf-8").strip()
                    if not line.startswith("data:"):
                        continue
                    raw = line[5:].strip()
                    if not raw or raw == "[DONE]":
                        continue
                    chunk = json.loads(raw)
                    error = chunk.get("error")
                    if error:
                        raise PraxoError(
                            f"gemini: {error.get('message', error)}"
                        )
                    usage = _parse_usage(chunk.get("usageMetadata") or {}, usage)
                    candidates = chunk.get("candidates") or []
                    if not candidates:
                        continue
                    candidate = candidates[0]
                    finish_reason = (
                        candidate.get("finishReason") or finish_reason
                    )
                    parts = (candidate.get("content") or {}).get("parts") or []
                    for part in parts:
                        text = part.get("text")
                        if text:
                            content.append(text)
                            on_delta(text)
                        call = part.get("functionCall")
                        if call:
                            calls.append(
                                ToolCall(
                                    id=f"call-{len(calls) + 1}",
                                    name=call.get("name") or "",
                                    arguments=call.get("args") or {},
                                )
                            )
        except HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise PraxoError(
                f"gemini: HTTP {exc.code}: {body[:512]}"
            ) from exc
        except URLError as exc:
            raise PraxoError(f"gemini: {exc.reason}") from exc
        return Response(
            message=Message(
                role=ROLE_ASSISTANT,
                content="".join(content),
                tool_calls=calls,
            ),
            usage=usage,
            finish_reason=finish_reason,
        )

    def _endpoint(self, stream: bool) -> str:
        base = self.config.base_url.rstrip("/")
        model = quote(self.config.model, safe="")
        suffix = ":streamGenerateContent?alt=sse" if stream else ":generateContent"
        return f"{base}/v1beta/models/{model}{suffix}"

    def _headers(self, stream: bool) -> dict[str, str]:
        headers = {
            "Content-Type": "application/json",
            "Accept": "text/event-stream" if stream else "application/json",
            "x-goog-api-key": self.config.api_key,
        }
        headers.update(self.config.headers)
        return headers

    def _parse_response(self, data: dict[str, Any]) -> Response:
        error = data.get("error")
        if error:
            raise PraxoError(f"gemini: {error.get('message', error)}")
        candidates = data.get("candidates") or []
        if not candidates:
            raise PraxoError("gemini: empty response")
        candidate = candidates[0]
        content, calls = _parse_parts(
            (candidate.get("content") or {}).get("parts") or []
        )
        return Response(
            message=Message(
                role=ROLE_ASSISTANT,
                content=content,
                tool_calls=calls,
            ),
            usage=_parse_usage(data.get("usageMetadata") or {}, Usage()),
            finish_reason=candidate.get("finishReason"),
        )


def _build_contents(
    messages: list[Message],
) -> tuple[dict[str, Any] | None, list[dict[str, Any]]]:
    system_parts: list[dict[str, Any]] = []
    contents: list[dict[str, Any]] = []
    tool_parts: list[dict[str, Any]] = []
    names: dict[str, str] = {}

    def flush() -> None:
        if tool_parts:
            contents.append({"role": "user", "parts": list(tool_parts)})
            tool_parts.clear()

    for message in messages:
        if message.role == ROLE_SYSTEM:
            if message.content:
                system_parts.append({"text": message.content})
            continue
        if message.role == ROLE_TOOL:
            name = names.get(message.tool_id or "") or message.tool_id or "tool"
            tool_parts.append(
                {
                    "functionResponse": {
                        "name": name,
                        "response": {"result": message.content},
                    }
                }
            )
            continue
        flush()
        parts = _message_parts(message)
        if not parts:
            continue
        contents.append(
            {
                "role": "model"
                if message.role == ROLE_ASSISTANT
                else "user",
                "parts": parts,
            }
        )
        for call in message.tool_calls:
            if call.id and call.name:
                names[call.id] = call.name
    flush()
    system = {"parts": system_parts} if system_parts else None
    return system, contents


def _message_parts(message: Message) -> list[dict[str, Any]]:
    parts: list[dict[str, Any]] = []
    if message.content:
        parts.append({"text": message.content})
    for block in message.content_blocks:
        if block.type == "text" and block.text:
            parts.append({"text": block.text})
    for call in message.tool_calls:
        parts.append(
            {
                "functionCall": {
                    "name": call.name,
                    "args": call.arguments,
                }
            }
        )
    return parts


def _tool_mode(choice: str | None) -> str:
    if choice == TOOL_CHOICE_REQUIRED:
        return "ANY"
    if choice == TOOL_CHOICE_NONE:
        return "NONE"
    return "AUTO"


def _parse_parts(
    parts: list[dict[str, Any]],
) -> tuple[str, list[ToolCall]]:
    text: list[str] = []
    calls: list[ToolCall] = []
    for part in parts:
        if part.get("text"):
            text.append(part["text"])
        call = part.get("functionCall")
        if call:
            calls.append(
                ToolCall(
                    id=f"call-{len(calls) + 1}",
                    name=call.get("name") or "",
                    arguments=call.get("args") or {},
                )
            )
    return "".join(text), calls


def _parse_usage(raw: dict[str, Any], fallback: Usage) -> Usage:
    if not raw:
        return fallback
    return Usage(
        input_tokens=int(raw.get("promptTokenCount", 0)),
        output_tokens=int(raw.get("candidatesTokenCount", 0)),
        cached_tokens=int(raw.get("cachedContentTokenCount", 0)),
    )
