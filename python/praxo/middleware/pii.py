from __future__ import annotations

import copy
import re
from dataclasses import dataclass, field
from typing import Any

from .base import Middleware, ModelCall, ToolCall, ToolResult


@dataclass
class PIIRule:
    name: str
    pattern: re.Pattern[str]
    replacement: str = ""


def new_pii_rule(name: str, pattern: str, replacement: str) -> PIIRule:
    return PIIRule(name=name, pattern=re.compile(pattern), replacement=replacement)


def default_pii_rules() -> list[PIIRule]:
    return [
        new_pii_rule(
            "email",
            r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}",
            "[REDACTED:email]",
        ),
        new_pii_rule("ssn", r"\b\d{3}-\d{2}-\d{4}\b", "[REDACTED:ssn]"),
        new_pii_rule(
            "credit_card",
            r"\b(?:\d{4}[ -]?){3}\d{4}\b",
            "[REDACTED:credit_card]",
        ),
        new_pii_rule(
            "phone",
            r"\b(?:\+?1[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}\b",
            "[REDACTED:phone]",
        ),
    ]


@dataclass
class PIIRedactor:
    rules: list[PIIRule] = field(default_factory=list)

    def redact(self, text: str) -> str:
        for rule in self.rules:
            if rule.pattern is None:
                continue
            replacement = rule.replacement or "[REDACTED]"
            text = rule.pattern.sub(replacement, text)
        return text


def redact_value(redactor: PIIRedactor, value: Any) -> Any:
    if isinstance(value, str):
        return redactor.redact(value)
    if isinstance(value, (bytes, bytearray)):
        return redactor.redact(bytes(value).decode("utf-8", errors="replace"))
    if isinstance(value, dict):
        return {key: redact_value(redactor, item) for key, item in value.items()}
    if isinstance(value, list):
        return [redact_value(redactor, item) for item in value]
    return value


def pii_middleware(redactor: PIIRedactor) -> Middleware:
    async def before_model(call: ModelCall) -> None:
        if call.request is None:
            return
        messages = copy.deepcopy(call.request.messages)
        for message in messages:
            message.content = redactor.redact(message.content)
            for block in message.content_blocks:
                block.text = redactor.redact(block.text or "")
        call.request.messages = messages

    async def after_tool(_: ToolCall, result: ToolResult) -> None:
        result.value = redact_value(redactor, result.value)

    return Middleware(
        name="pii",
        before_model=before_model,
        after_tool=after_tool,
    )
