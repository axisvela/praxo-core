from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable

from ..errors import StructuredOutputError
from ..jsonschema import Schema
from ..model import ResponseFormat, ToolSpec
from .base import Middleware, ModelCall, maybe_await

STRATEGY_AUTO = "auto"
STRATEGY_PROVIDER = "provider"
STRATEGY_TOOL = "tool"

ValidateFunc = Callable[[str], Awaitable[None] | None]
RepairFunc = Callable[[str, BaseException], Awaitable[str] | str]


@dataclass
class StructuredOutput:
    schema: dict[str, Any] = field(default_factory=dict)
    name: str = ""
    strategy: str = STRATEGY_AUTO
    max_repairs: int = 0
    validate: ValidateFunc | None = None
    repair: RepairFunc | None = None

    def output_name(self) -> str:
        return self.name.strip() or "structured_output"

    def response_format(self) -> ResponseFormat | None:
        if self.strategy == STRATEGY_TOOL or not self.schema:
            return None
        return ResponseFormat(name=self.output_name(), schema=self.schema)

    def tool_spec(self) -> ToolSpec:
        return ToolSpec(
            name=self.output_name(),
            description=(
                "Return the final answer as structured JSON matching the "
                "response schema."
            ),
            parameters=self.schema,
            risk="low",
        )

    def middleware(self) -> Middleware:
        async def before_model(call: ModelCall) -> None:
            if call.request is None:
                return
            if call.request.response_format is None:
                call.request.response_format = self.response_format()
            if self.strategy == STRATEGY_TOOL:
                for spec in call.request.tools:
                    if spec.name == self.output_name():
                        call.request.tool_choice = "required"
                        break

        async def after_run(result: Any, error: BaseException | None) -> None:
            if error is not None or result is None:
                return
            await self.apply(result)

        return Middleware(
            name="structured-output",
            before_model=before_model,
            after_run=after_run,
        )

    async def apply(self, result: Any) -> None:
        output = result.output
        last_error: BaseException | None = None
        for attempt in range(self.max_repairs + 1):
            try:
                await self._validate(output)
                result.output = output
                return
            except Exception as exc:
                last_error = exc
            if attempt == self.max_repairs or self.repair is None:
                break
            repaired = await maybe_await(self.repair(output, last_error))
            if not repaired.strip():
                raise StructuredOutputError(
                    "agent: structured output validation failed: "
                    "repair returned empty output"
                )
            output = repaired
        raise StructuredOutputError(
            f"agent: structured output validation failed: {last_error}"
        )

    async def validate_arguments(self, arguments: dict[str, Any]) -> None:
        if self.validate is not None:
            await maybe_await(self.validate(json.dumps(arguments)))
            return
        errors = Schema.from_dict(self.schema).validate(arguments)
        if errors:
            detail = ", ".join(f"{item.path}: {item.message}" for item in errors)
            raise StructuredOutputError(f"schema: {detail}")

    async def _validate(self, output: str) -> None:
        if self.validate is not None:
            await maybe_await(self.validate(output))
            return
        data = extract_json(output)
        errors = Schema.from_dict(self.schema).validate(data)
        if errors:
            detail = ", ".join(f"{item.path}: {item.message}" for item in errors)
            raise StructuredOutputError(f"schema: {detail}")


def extract_json(output: str) -> Any:
    text = output.strip()
    if not text:
        raise ValueError("empty output")
    if text.startswith("```"):
        newline = text.find("\n")
        if newline >= 0:
            text = text[newline + 1 :]
        text = text.rstrip().removesuffix("```").strip()
    start = _first_index(text, "{", "[")
    if start < 0:
        raise ValueError("output does not contain JSON")
    text = text[start:]
    try:
        return json.loads(text)
    except ValueError as exc:
        raise ValueError(f"decode JSON: {exc}") from exc


def _first_index(text: str, *needles: str) -> int:
    found = [text.find(needle) for needle in needles]
    found = [index for index in found if index >= 0]
    return min(found) if found else -1
