from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable

from .model import ToolCall

INTERRUPT_APPROVE = "approve"
INTERRUPT_EDIT = "edit"
INTERRUPT_REJECT = "reject"
INTERRUPT_RESPOND = "respond"


@dataclass(frozen=True)
class Interrupt:
    run_id: str
    session_id: str
    call: ToolCall


@dataclass
class InterruptDecision:
    action: str
    arguments: dict[str, Any] | None = None
    response: str = ""
    reason: str = ""


InterruptHandler = Callable[
    [Interrupt], InterruptDecision | Awaitable[InterruptDecision]
]
InterruptApproval = Callable[[Interrupt], bool | Awaitable[bool]]


__all__ = [
    "INTERRUPT_APPROVE",
    "INTERRUPT_EDIT",
    "INTERRUPT_REJECT",
    "INTERRUPT_RESPOND",
    "Interrupt",
    "InterruptApproval",
    "InterruptDecision",
    "InterruptHandler",
]
