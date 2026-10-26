from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable

from ..model import Request, Response, ToolCall as ModelToolCall


@dataclass
class RunState:
    run_id: str
    session: Any
    prompt: str


@dataclass
class ModelCall:
    run_id: str
    session_id: str
    request: Request
    skip: bool = False
    response: Response | None = None


@dataclass
class ToolCall:
    run_id: str
    session_id: str
    call: ModelToolCall
    skip: bool = False
    result: Any = None
    error: BaseException | None = None


@dataclass
class ToolResult:
    value: Any = None
    error: BaseException | None = None


BeforeRun = Callable[[RunState], Awaitable[None] | None]
BeforeModel = Callable[[ModelCall], Awaitable[None] | None]
AfterModel = Callable[[ModelCall, Response], Awaitable[None] | None]
BeforeTool = Callable[[ToolCall], Awaitable[None] | None]
AfterTool = Callable[[ToolCall, ToolResult], Awaitable[None] | None]
AfterRun = Callable[[Any, BaseException | None], Awaitable[None] | None]


@dataclass
class Middleware:
    name: str = ""
    before_run: BeforeRun | None = None
    before_model: BeforeModel | None = None
    after_model: AfterModel | None = None
    before_tool: BeforeTool | None = None
    after_tool: AfterTool | None = None
    after_run: AfterRun | None = None


ModelHandler = Callable[[Request], Awaitable[Response]]
ModelMiddleware = Callable[[ModelHandler], ModelHandler]


async def maybe_await(value: Any) -> Any:
    if hasattr(value, "__await__"):
        return await value
    return value


def merge_middleware(items: list[Middleware]) -> list[Middleware]:
    out: list[Middleware] = []
    index: dict[str, int] = {}
    for item in items:
        if not item.name:
            out.append(item)
            continue
        if item.name in index:
            out[index[item.name]] = item
            continue
        index[item.name] = len(out)
        out.append(item)
    return out


__all__ = [
    "AfterModel",
    "AfterRun",
    "AfterTool",
    "BeforeModel",
    "BeforeRun",
    "BeforeTool",
    "Middleware",
    "ModelCall",
    "ModelHandler",
    "ModelMiddleware",
    "RunState",
    "ToolCall",
    "ToolResult",
    "maybe_await",
    "merge_middleware",
]
