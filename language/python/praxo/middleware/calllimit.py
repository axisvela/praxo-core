from __future__ import annotations

import asyncio
from contextvars import ContextVar
from dataclasses import dataclass

from ..errors import ModelCallLimitError, ToolCallLimitError
from .base import Middleware, ModelCall, RunState, ToolCall


@dataclass
class _Count:
    models: int = 0
    tools: int = 0


def call_limit_middleware(model_limit: int, tool_limit: int) -> Middleware:
    counts: dict[str, _Count] = {}
    lock = asyncio.Lock()
    active: ContextVar[tuple[str, ...]] = ContextVar(
        "praxo_call_limit_runs", default=()
    )

    async def before_run(state: RunState) -> None:
        active.set(active.get() + (state.run_id,))
        async with lock:
            counts[state.run_id] = _Count()

    async def before_model(call: ModelCall) -> None:
        async with lock:
            count = counts.setdefault(call.run_id, _Count())
            count.models += 1
            if model_limit > 0 and count.models > model_limit:
                raise ModelCallLimitError(
                    "agent: model call limit exceeded"
                )

    async def before_tool(call: ToolCall) -> None:
        async with lock:
            count = counts.setdefault(call.run_id, _Count())
            count.tools += 1
            if tool_limit > 0 and count.tools > tool_limit:
                raise ToolCallLimitError(
                    "agent: tool call limit exceeded"
                )

    async def after_run(result: object, error: BaseException | None) -> None:
        run_id = ""
        runs = active.get()
        if runs:
            run_id = runs[-1]
            active.set(runs[:-1])
        if not run_id:
            run_id = getattr(result, "run_id", "")
        if not run_id:
            return
        async with lock:
            counts.pop(run_id, None)

    return Middleware(
        name="call-limit",
        before_run=before_run,
        before_model=before_model,
        before_tool=before_tool,
        after_run=after_run,
    )
