from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from typing import Any, Callable

from .errors import MaxStepsError, MaxTokensError, PolicyDeniedError, ToolNotFoundError
from .event import Event, Sink
from .model import (
    ROLE_SYSTEM,
    ROLE_TOOL,
    ROLE_USER,
    Message,
    Model,
    Request,
    Response,
    Usage,
)
from .policy import Action, Hook
from .tool import Registry


@dataclass
class Session:
    id: str
    tenant_id: str = "default"
    workspace_id: str = ""
    messages: list[Message] = field(default_factory=list)


@dataclass
class Result:
    run_id: str
    output: str
    steps: int
    usage: Usage = field(default_factory=Usage)


@dataclass
class AgentOptions:
    model: Model
    tools: Registry | None = None
    events: Sink | None = None
    policy: Hook | None = None
    system_prompt: str = ""
    max_steps: int = 8
    max_tokens: int = 0
    max_parallel_tools: int = 1
    on_delta: Callable[[str], Any] | None = None


class Agent:
    def __init__(self, options: AgentOptions) -> None:
        self.options = options

    async def run(self, session: Session, prompt: str) -> Result:
        model = self.options.model
        if model is None:
            raise ValueError("agent: model is required")
        max_steps = self.options.max_steps if self.options.max_steps > 0 else 8
        run_id = f"run-{time.time_ns()}"
        messages = list(session.messages)
        if self.options.system_prompt:
            messages.insert(
                0, Message(role=ROLE_SYSTEM, content=self.options.system_prompt)
            )
        messages.append(Message(role=ROLE_USER, content=prompt))
        usage = Usage()

        await self._emit(Event("run.started", session.id, run_id))
        try:
            for step in range(1, max_steps + 1):
                await self._authorize(
                    Action(kind="model.generate", session_id=session.id)
                )
                request = Request(
                    messages=messages,
                    tools=self.options.tools.specs()
                    if self.options.tools is not None
                    else [],
                )
                if self.options.on_delta is not None and callable(
                    getattr(model, "generate_stream", None)
                ):
                    response = await model.generate_stream(
                        request, self.options.on_delta
                    )
                else:
                    response = await model.generate(request)
                usage = Usage(
                    input_tokens=usage.input_tokens + response.usage.input_tokens,
                    output_tokens=usage.output_tokens + response.usage.output_tokens,
                    cached_tokens=usage.cached_tokens + response.usage.cached_tokens,
                )
                if (
                    self.options.max_tokens > 0
                    and usage.input_tokens + usage.output_tokens
                    > self.options.max_tokens
                ):
                    raise MaxTokensError("agent: max tokens exceeded")
                messages.append(response.message)
                if not response.message.tool_calls:
                    result = Result(
                        run_id=run_id,
                        output=response.message.content,
                        steps=step,
                        usage=usage,
                    )
                    await self._emit(Event("run.completed", session.id, run_id))
                    return result
                for call in response.message.tool_calls:
                    await self._authorize(
                        Action(
                            kind="tool.invoke",
                            session_id=session.id,
                            tool_name=call.name,
                            arguments=call.arguments,
                        )
                    )
                    if self.options.tools is None:
                        raise ToolNotFoundError(
                            f"tool {call.name} is not registered"
                        )
                    tool = self.options.tools.get(call.name)
                    await self._emit(
                        Event(
                            "tool.call",
                            session.id,
                            run_id,
                            {"name": call.name, "arguments": call.arguments},
                        )
                    )
                    value = await tool.invoke(call.arguments)
                    messages.append(
                        Message(
                            role=ROLE_TOOL,
                            content=_stringify(value),
                            tool_id=call.id,
                        )
                    )
            raise MaxStepsError("agent: max steps exceeded")
        except Exception as exc:
            try:
                await self._emit(
                    Event("run.failed", session.id, run_id, {"error": str(exc)})
                )
            except Exception:
                pass
            raise

    async def _authorize(self, action: Action) -> None:
        if self.options.policy is None:
            return
        decision = await self.options.policy.authorize(action)
        if not decision.allowed:
            raise PolicyDeniedError(
                f"agent: {action.kind} denied: {decision.reason}"
            )

    async def _emit(self, event: Event) -> None:
        if self.options.events is None:
            return
        await self.options.events.emit(event)


def _stringify(value: Any) -> str:
    if isinstance(value, str):
        return value
    try:
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError):
        return str(value)
