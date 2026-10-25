from __future__ import annotations

import json
from dataclasses import dataclass, field, is_dataclass
from datetime import datetime
from typing import Any, Callable, Protocol, runtime_checkable

from .errors import CheckpointError, TypeNotAllowedError


@dataclass
class Envelope:
    type: str
    data: Any


@dataclass
class Message:
    role: str
    content: str = ""
    content_blocks: Any = None

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {"role": self.role, "content": self.content}
        if self.content_blocks is not None:
            out["content_blocks"] = self.content_blocks
        return out


@dataclass
class RunSnapshot:
    id: str
    session_id: str
    status: str
    created_at: datetime | None = None

    def to_wire(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "session_id": self.session_id,
            "status": self.status,
            "created_at": (
                self.created_at.isoformat() if self.created_at is not None else None
            ),
        }


@dataclass
class EffectCursor:
    run_id: str
    last_effect_id: str
    last_created_at: int


@dataclass
class Checkpoint:
    id: str
    session_id: str
    run_id: str
    status: str
    version: int = 0
    title: str = ""
    model_id: str = ""
    tenant_id: str = ""
    workspace_id: str = ""
    parent_session_id: str = ""
    parent_run_id: str = ""
    agent_id: str = ""
    messages: list[Message] = field(default_factory=list)
    runs: list[RunSnapshot] = field(default_factory=list)
    effect_cursor: EffectCursor | None = None
    created_at: datetime | None = None


@runtime_checkable
class Store(Protocol):
    async def save(self, checkpoint: Checkpoint) -> None: ...

    async def load(self, session_id: str) -> Checkpoint | None: ...

    async def load_scoped(
        self, tenant_id: str, session_id: str
    ) -> Checkpoint | None: ...

    async def load_run(self, run_id: str) -> Checkpoint | None: ...

    async def load_run_scoped(
        self, tenant_id: str, run_id: str
    ) -> Checkpoint | None: ...

    async def list(self, session_id: str) -> list[Checkpoint]: ...

    async def delete(self, checkpoint_id: str) -> None: ...


class Allowlist:
    def __init__(self) -> None:
        self._factories: dict[str, Callable[[], Any]] = {}

    def register(self, name: str, factory: Callable[[], Any]) -> None:
        if not name:
            raise CheckpointError("checkpoint: allowlist type name is required")
        if factory is None:
            raise CheckpointError("checkpoint: allowlist factory is required")
        self._factories[name] = factory

    def marshal(self, name: str, value: Any) -> bytes:
        if name not in self._factories:
            raise TypeNotAllowedError(f"checkpoint: payload type not allowed: {name}")
        envelope = {"type": name, "data": value}
        return json.dumps(envelope, separators=(",", ":")).encode("utf-8")

    def unmarshal(self, data: bytes | str) -> Any:
        if isinstance(data, bytes):
            data = data.decode("utf-8")
        raw = json.loads(data)
        if not isinstance(raw, dict):
            raise CheckpointError("checkpoint: envelope must be an object")
        name = raw.get("type", "")
        factory = self._factories.get(name)
        if factory is None:
            raise TypeNotAllowedError(
                f"checkpoint: payload type not allowed: {name}"
            )
        target = factory()
        if target is None:
            raise CheckpointError(f"checkpoint: factory for {name} returned nil")
        payload = raw.get("data")
        return _populate(target, payload)


def _populate(target: Any, payload: Any) -> Any:
    if isinstance(target, dict):
        if isinstance(payload, dict):
            target.update(payload)
        return target
    if is_dataclass(target) and not isinstance(target, type):
        if isinstance(payload, dict):
            return type(target)(**payload)
        return target
    return payload
