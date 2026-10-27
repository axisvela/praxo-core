from __future__ import annotations

import asyncio
from typing import Any, Protocol, runtime_checkable

from ..errors import ToolNotSelectedError
from ..model import Model, Request, ROLE_SYSTEM, ROLE_USER, ToolSpec, Message
from .base import (
    Middleware,
    ModelCall,
    ToolCall,
    maybe_await,
)
from .structured import extract_json

DEFAULT_TOOL_SELECTOR_PROMPT = """Select the tools needed to answer the user query.
Return only JSON in the form {"tools":["tool_name"]}.
Prefer the smallest sufficient set. Return {"tools":[]} when no tool is needed."""


@runtime_checkable
class ToolSelector(Protocol):
    async def select(
        self, query: str, tools: list[ToolSpec]
    ) -> list[str]: ...


def tool_selection_middleware(selector: ToolSelector | None) -> Middleware:
    selected: dict[str, set[str]] = {}
    lock = asyncio.Lock()

    async def before_model(call: ModelCall) -> None:
        if call.request is None or selector is None:
            return
        names = await maybe_await(
            selector.select(
                last_user_message(call.request.messages),
                call.request.tools,
            )
        )
        chosen = set(names or [])
        async with lock:
            selected[call.run_id] = chosen
        call.request.tools = [
            spec for spec in call.request.tools if spec.name in chosen
        ]

    async def before_tool(call: ToolCall) -> None:
        if call.call is None:
            return
        async with lock:
            chosen = selected.get(call.run_id)
        if chosen is None:
            return
        if call.call.name not in chosen:
            raise ToolNotSelectedError("agent: tool not selected")

    async def after_run(result: Any, error: BaseException | None) -> None:
        if result is None:
            return
        run_id = getattr(result, "run_id", "")
        async with lock:
            selected.pop(run_id, None)

    return Middleware(
        name="tool-selection",
        before_model=before_model,
        before_tool=before_tool,
        after_run=after_run,
    )


def last_user_message(messages: list[Message]) -> str:
    for message in reversed(messages):
        if message.role == ROLE_USER:
            return message.content
    return ""


class ModelToolSelector:
    def __init__(
        self,
        model: Model | None,
        prompt: str = "",
        max_tools: int = 0,
    ) -> None:
        self.model = model
        self.prompt = prompt
        self.max_tools = max_tools

    async def select(
        self, query: str, tools: list[ToolSpec]
    ) -> list[str]:
        if self.model is None:
            raise ValueError("agent: tool selector model is required")
        if not tools:
            return []
        prompt = self.prompt.strip() or DEFAULT_TOOL_SELECTOR_PROMPT
        catalog = "".join(
            f"\n- {spec.name}: {spec.description}" for spec in tools
        )
        request = Request(
            messages=[
                Message(role=ROLE_SYSTEM, content=prompt),
                Message(
                    role=ROLE_USER,
                    content=f"Query: {query}\nAvailable tools:{catalog}",
                ),
            ]
        )
        response = await self.model.generate(request)
        try:
            parsed = extract_json(response.message.content)
            requested = parsed.get("tools", [])
        except Exception as exc:
            raise ValueError(
                f"agent: tool selector response: {exc}"
            ) from exc
        known = {spec.name for spec in tools}
        seen: set[str] = set()
        out: list[str] = []
        for name in requested:
            if name not in known or name in seen:
                continue
            seen.add(name)
            out.append(name)
            if self.max_tools > 0 and len(out) >= self.max_tools:
                break
        return out
