from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol, runtime_checkable

ROLE_SYSTEM = "system"
ROLE_USER = "user"
ROLE_ASSISTANT = "assistant"
ROLE_TOOL = "tool"

TOOL_CHOICE_AUTO = "auto"
TOOL_CHOICE_NONE = "none"
TOOL_CHOICE_REQUIRED = "required"


@dataclass
class ContentBlock:
    type: str
    text: str | None = None
    image_url: str | None = None
    data: str | None = None

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {"type": self.type}
        if self.text is not None:
            out["text"] = self.text
        if self.image_url is not None:
            out["image_url"] = self.image_url
        if self.data is not None:
            out["data"] = self.data
        return out

    @classmethod
    def from_wire(cls, raw: dict[str, Any]) -> ContentBlock:
        return cls(
            type=raw.get("type", ""),
            text=raw.get("text"),
            image_url=raw.get("image_url"),
            data=raw.get("data"),
        )


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict[str, Any] = field(default_factory=dict)

    def to_wire(self) -> dict[str, Any]:
        return {"id": self.id, "name": self.name, "arguments": self.arguments}

    @classmethod
    def from_wire(cls, raw: dict[str, Any]) -> ToolCall:
        return cls(
            id=raw.get("id", ""),
            name=raw.get("name", ""),
            arguments=raw.get("arguments") or {},
        )


@dataclass
class Message:
    role: str
    content: str = ""
    content_blocks: list[ContentBlock] = field(default_factory=list)
    tool_calls: list[ToolCall] = field(default_factory=list)
    tool_id: str | None = None

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {"role": self.role}
        if self.content:
            out["content"] = self.content
        if self.content_blocks:
            out["contentBlocks"] = [b.to_wire() for b in self.content_blocks]
        if self.tool_calls:
            out["toolCalls"] = [c.to_wire() for c in self.tool_calls]
        if self.tool_id is not None:
            out["toolId"] = self.tool_id
        return out

    @classmethod
    def from_wire(cls, raw: dict[str, Any]) -> Message:
        return cls(
            role=raw.get("role", ""),
            content=raw.get("content", ""),
            content_blocks=[
                ContentBlock.from_wire(b) for b in raw.get("contentBlocks", [])
            ],
            tool_calls=[ToolCall.from_wire(c) for c in raw.get("toolCalls", [])],
            tool_id=raw.get("toolId"),
        )


@dataclass
class ToolSpec:
    name: str
    description: str = ""
    parameters: dict[str, Any] | None = None
    risk: str | None = None

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {"name": self.name, "description": self.description}
        if self.parameters is not None:
            out["parameters"] = self.parameters
        if self.risk is not None:
            out["risk"] = self.risk
        return out


@dataclass
class ResponseFormat:
    name: str = ""
    schema: dict[str, Any] | None = None

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {}
        if self.name:
            out["name"] = self.name
        if self.schema is not None:
            out["schema"] = self.schema
        return out


@dataclass
class CacheHint:
    stable_prefix: int = 0
    ttl: str | None = None

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {}
        if self.stable_prefix:
            out["stablePrefix"] = self.stable_prefix
        if self.ttl is not None:
            out["ttl"] = self.ttl
        return out


@dataclass
class Usage:
    input_tokens: int = 0
    output_tokens: int = 0
    cached_tokens: int = 0

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {
            "inputTokens": self.input_tokens,
            "outputTokens": self.output_tokens,
        }
        if self.cached_tokens:
            out["cachedTokens"] = self.cached_tokens
        return out


@dataclass
class Request:
    messages: list[Message] = field(default_factory=list)
    model: str | None = None
    tools: list[ToolSpec] = field(default_factory=list)
    tool_choice: str | None = None
    response_format: ResponseFormat | None = None
    cache_hint: CacheHint | None = None
    temperature: float = 0.0

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {"messages": [m.to_wire() for m in self.messages]}
        if self.model is not None:
            out["model"] = self.model
        if self.tools:
            out["tools"] = [t.to_wire() for t in self.tools]
        if self.tool_choice is not None:
            out["toolChoice"] = self.tool_choice
        if self.response_format is not None:
            out["responseFormat"] = self.response_format.to_wire()
        if self.cache_hint is not None:
            out["cacheHint"] = self.cache_hint.to_wire()
        if self.temperature:
            out["temperature"] = self.temperature
        return out


@dataclass
class Response:
    message: Message
    usage: Usage = field(default_factory=Usage)
    finish_reason: str | None = None

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {
            "message": self.message.to_wire(),
            "usage": self.usage.to_wire(),
        }
        if self.finish_reason is not None:
            out["finishReason"] = self.finish_reason
        return out


@dataclass
class StreamEvent:
    delta: str = ""
    done: bool = False


@runtime_checkable
class Model(Protocol):
    async def generate(self, request: Request) -> Response: ...


@runtime_checkable
class StreamingModel(Model, Protocol):
    async def generate_stream(self, request: Request, on_delta: Any) -> Response: ...


@runtime_checkable
class Provider(Protocol):
    async def chat(self, messages: list[Message]) -> list[Message]: ...

    def chat_stream(self, messages: list[Message]) -> Any: ...


@runtime_checkable
class ModelRouter(Protocol):
    def route(self, task_class: str) -> Provider: ...


class ChatModel:
    def __init__(self, provider: Provider) -> None:
        self.provider = provider

    async def generate(self, request: Request) -> Response:
        if self.provider is None:
            raise ValueError("model: provider is required")
        messages = await self.provider.chat(request.messages)
        if not messages:
            raise ValueError("model: provider returned no messages")
        return Response(message=messages[-1])
