from __future__ import annotations

import copy
import json
import time
from dataclasses import dataclass, field
from typing import Any, Callable

from .context import (
    ContextBudget,
    ContextCompactor,
    Offloader,
    estimate_tokens,
    load_agents_md,
)
from .errors import (
    ContextBudgetError,
    MaxStepsError,
    MaxTokensError,
    PolicyDeniedError,
    ToolNotFoundError,
)
from .event import Event, Sink
from .middleware import (
    Middleware,
    ModelCall,
    ModelMiddleware,
    RunState,
    PIIRedactor,
    StructuredOutput,
    ToolCall as MiddlewareToolCall,
    ToolResult,
    ToolSelector,
    call_limit_middleware,
    fallback_model,
    maybe_await,
    merge_middleware,
    pii_middleware,
    tool_selection_middleware,
)
from .model import (
    ROLE_SYSTEM,
    ROLE_TOOL,
    ROLE_USER,
    Message,
    Model,
    Request,
    Response,
    ResponseFormat,
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
    memory_files: list[str] = field(default_factory=list)
    context: ContextBudget | None = None
    compactor: ContextCompactor | None = None
    offloader: Offloader | None = None
    offload_threshold_bytes: int = 0
    middleware: list[Middleware] = field(default_factory=list)
    model_middleware: list[ModelMiddleware] = field(default_factory=list)
    structured_output: StructuredOutput | None = None
    allowed_tools: list[str] = field(default_factory=list)
    tool_selector: ToolSelector | None = None
    pii_redactor: PIIRedactor | None = None
    model_call_limit: int = 0
    tool_call_limit: int = 0
    fallback_model: Model | None = None
    tool_choice: str | None = None
    response_format: ResponseFormat | None = None
    max_steps: int = 8
    max_tokens: int = 0
    max_parallel_tools: int = 1
    on_delta: Callable[[str], Any] | None = None


class Agent:
    def __init__(self, options: AgentOptions) -> None:
        self.options = options
        system_prompt = options.system_prompt
        memory = load_agents_md(options.memory_files)
        if memory:
            system_prompt = (system_prompt + "\n\n" + memory).strip()
        self.system_prompt = system_prompt

        middleware = list(options.middleware)
        if options.structured_output is not None:
            middleware.append(options.structured_output.middleware())
        if options.tool_selector is not None:
            middleware.append(tool_selection_middleware(options.tool_selector))
        if options.pii_redactor is not None:
            middleware.append(pii_middleware(options.pii_redactor))
        if options.model_call_limit > 0 or options.tool_call_limit > 0:
            middleware.append(
                call_limit_middleware(
                    options.model_call_limit, options.tool_call_limit
                )
            )
        self.middleware = merge_middleware(middleware)

        model_middleware = list(options.model_middleware)
        if options.fallback_model is not None:
            model_middleware.append(fallback_model(options.fallback_model))
        self.model_middleware = model_middleware

    async def run(self, session: Session, prompt: str) -> Result:
        model = self.options.model
        if model is None:
            raise ValueError("agent: model is required")
        max_steps = self.options.max_steps if self.options.max_steps > 0 else 8
        run_id = f"run-{time.time_ns()}"
        messages = list(session.messages)
        if self.system_prompt:
            messages.insert(
                0, Message(role=ROLE_SYSTEM, content=self.system_prompt)
            )
        messages.append(Message(role=ROLE_USER, content=prompt))
        usage = Usage()

        entered: list[Middleware] = []
        try:
            await self._before_run(RunState(run_id, session, prompt), entered)
        except BaseException as exc:
            try:
                await self._after_run(entered, None, exc)
            except BaseException:
                pass
            raise
        await self._emit(Event("run.started", session.id, run_id))
        after_run_invoked = False
        try:
            for step in range(1, max_steps + 1):
                await self._authorize(
                    Action(kind="model.generate", session_id=session.id)
                )
                messages = await self._compact(messages)
                request = Request(
                    messages=messages,
                    tools=self._tool_specs(),
                    tool_choice=self.options.tool_choice,
                    response_format=self.options.response_format,
                )
                model_call = ModelCall(run_id, session.id, request)
                await self._before_model(model_call)
                if model_call.skip:
                    if model_call.response is None:
                        raise ValueError(
                            "agent: model middleware skipped without a response"
                        )
                    response = model_call.response
                else:
                    response = await self._generate(model_call.request)
                await self._after_model(model_call, response)
                usage = Usage(
                    input_tokens=usage.input_tokens + response.usage.input_tokens,
                    output_tokens=usage.output_tokens
                    + response.usage.output_tokens,
                    cached_tokens=usage.cached_tokens
                    + response.usage.cached_tokens,
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
                    after_run_invoked = True
                    cleanup_error = await self._after_run(entered, result, None)
                    if cleanup_error is not None:
                        raise cleanup_error
                    await self._emit(
                        Event("run.completed", session.id, run_id)
                    )
                    return result
                for call in response.message.tool_calls:
                    messages.append(
                        await self._invoke_tool(call, run_id, session.id)
                    )
            raise MaxStepsError("agent: max steps exceeded")
        except BaseException as exc:
            if not after_run_invoked:
                try:
                    await self._after_run(entered, None, exc)
                except BaseException:
                    pass
            try:
                await self._emit(
                    Event("run.failed", session.id, run_id, {"error": str(exc)})
                )
            except BaseException:
                pass
            raise

    async def _compact(self, messages: list[Message]) -> list[Message]:
        budget = self.options.context
        if budget is None or budget.max_tokens <= 0:
            return messages
        if (
            self.options.compactor is not None
            and estimate_tokens(messages) > budget.max_tokens
        ):
            messages = await self.options.compactor.compact(messages, budget)
        out, ok = budget.compact(messages)
        if not ok:
            raise ContextBudgetError("agent: context budget exceeded")
        return out

    def _tool_specs(self) -> list[Any]:
        if self.options.tools is None:
            return []
        specs = self.options.tools.specs()
        if self.options.allowed_tools:
            allowed = set(self.options.allowed_tools)
            specs = [spec for spec in specs if spec.name in allowed]
        return specs

    def _tool_allowed(self, name: str) -> bool:
        return not self.options.allowed_tools or name in self.options.allowed_tools

    async def _generate(self, request: Request) -> Response:
        model = self.options.model

        async def base(req: Request) -> Response:
            if self.options.on_delta is not None and callable(
                getattr(model, "generate_stream", None)
            ):
                return await model.generate_stream(req, self.options.on_delta)
            return await model.generate(req)

        handler = base
        for middleware in reversed(self.model_middleware):
            handler = middleware(handler)
        return await handler(request)

    async def _invoke_tool(
        self, call: Any, run_id: str, session_id: str
    ) -> Message:
        original_name = call.name
        original_arguments = copy.deepcopy(call.arguments)
        if not self._tool_allowed(original_name):
            raise ValueError(f"agent: tool {original_name} is not allowed")
        await self._authorize(
            Action(
                kind="tool.invoke",
                session_id=session_id,
                tool_name=original_name,
                arguments=copy.deepcopy(original_arguments),
            )
        )
        if self.options.tools is None:
            raise ToolNotFoundError(f"tool {original_name} is not registered")
        tool_call = MiddlewareToolCall(run_id, session_id, call)
        await self._before_tool(tool_call)
        active = tool_call.call
        if tool_call.skip:
            value = tool_call.result
            error = tool_call.error
        else:
            if not self._tool_allowed(active.name):
                raise ValueError(f"agent: tool {active.name} is not allowed")
            if (
                active.name != original_name
                or active.arguments != original_arguments
            ):
                await self._authorize(
                    Action(
                        kind="tool.invoke",
                        session_id=session_id,
                        tool_name=active.name,
                        arguments=copy.deepcopy(active.arguments),
                    )
                )
            tool = self.options.tools.get(active.name)
            await self._emit(
                Event(
                    "tool.call",
                    session_id,
                    run_id,
                    {
                        "name": active.name,
                        "arguments": copy.deepcopy(active.arguments),
                    },
                )
            )
            try:
                value = await tool.invoke(copy.deepcopy(active.arguments))
                error = None
            except Exception as exc:
                value = None
                error = exc
        result = ToolResult(value=value, error=error)
        await self._after_tool(tool_call, result)
        if result.error is not None:
            raise result.error
        try:
            raw = json.dumps(
                result.value, ensure_ascii=False, separators=(",", ":")
            ).encode("utf-8")
        except (TypeError, ValueError) as exc:
            raise ValueError(
                f"agent: tool {active.name} result is not JSON-serializable: {exc}"
            ) from exc
        content = raw.decode("utf-8")
        if (
            self.options.offloader is not None
            and self.options.offload_threshold_bytes > 0
            and len(raw) > self.options.offload_threshold_bytes
        ):
            ref = await self.options.offloader.offload(
                active.name, active.id, raw
            )
            if not ref:
                raise ValueError("agent: offloader returned an empty placeholder")
            content = ref
        return Message(role=ROLE_TOOL, content=content, tool_id=active.id)

    async def _before_run(
        self, state: RunState, entered: list[Middleware]
    ) -> None:
        for middleware in self.middleware:
            entered.append(middleware)
            if middleware.before_run is not None:
                await maybe_await(middleware.before_run(state))

    async def _before_model(self, call: ModelCall) -> None:
        for middleware in self.middleware:
            if middleware.before_model is not None:
                await maybe_await(middleware.before_model(call))
            if call.skip:
                break

    async def _after_model(
        self, call: ModelCall, response: Response
    ) -> None:
        for middleware in self.middleware:
            if middleware.after_model is not None:
                await maybe_await(middleware.after_model(call, response))

    async def _before_tool(self, call: MiddlewareToolCall) -> None:
        for middleware in self.middleware:
            if middleware.before_tool is not None:
                await maybe_await(middleware.before_tool(call))
            if call.skip:
                break

    async def _after_tool(
        self, call: MiddlewareToolCall, result: ToolResult
    ) -> None:
        for middleware in self.middleware:
            if middleware.after_tool is not None:
                await maybe_await(middleware.after_tool(call, result))

    async def _after_run(
        self,
        entered: list[Middleware],
        result: Result | None,
        error: BaseException | None,
    ) -> BaseException | None:
        first_error: BaseException | None = None
        for middleware in entered:
            if middleware.after_run is None:
                continue
            try:
                await maybe_await(middleware.after_run(result, error))
            except BaseException as exc:
                if first_error is None:
                    first_error = exc
                if error is None:
                    error = exc
        return first_error

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
