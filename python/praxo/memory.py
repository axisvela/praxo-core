from __future__ import annotations

import uuid
from dataclasses import dataclass, field, replace
from datetime import datetime, timezone
from typing import Any, Protocol, runtime_checkable

Frame = str

FRAME_EVENT = "event"
FRAME_DECISION = "decision"
FRAME_EXPERIENCE = "experience"
FRAME_PROCEDURE = "procedure"
FRAME_WORKSPACE_STATE = "workspace_state"
FRAME_CONSTRAINT = "constraint"
FRAME_INTENTION = "intention"


@dataclass
class Record:
    id: str = ""
    frame: str = FRAME_EVENT
    content: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)
    created_at: datetime | None = None

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {
            "id": self.id,
            "frame": self.frame,
            "content": self.content,
            "createdAt": (
                self.created_at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
                if self.created_at is not None
                else None
            ),
        }
        if self.metadata:
            out["metadata"] = self.metadata
        return out

    @classmethod
    def from_wire(cls, raw: dict[str, Any]) -> Record:
        created = raw.get("createdAt")
        return cls(
            id=raw.get("id", ""),
            frame=raw.get("frame", FRAME_EVENT),
            content=raw.get("content", ""),
            metadata=raw.get("metadata") or {},
            created_at=(
                datetime.fromisoformat(created.replace("Z", "+00:00"))
                if created
                else None
            ),
        )


@runtime_checkable
class Store(Protocol):
    async def put(self, session_id: str, record: Record) -> None: ...

    async def search(
        self, session_id: str, query: str, limit: int = 0
    ) -> list[Record]: ...


@dataclass
class _Stored:
    record: Record
    search: str


class MemoryStore:
    def __init__(self) -> None:
        self._records: dict[str, list[_Stored]] = {}

    async def put(self, session_id: str, record: Record) -> None:
        if not record.id:
            record = replace(record, id=f"mem-{uuid.uuid4().hex}")
        if record.created_at is None:
            record = replace(record, created_at=datetime.now(timezone.utc))
        self._records.setdefault(session_id, []).append(
            _Stored(record=record, search=record.content.lower())
        )

    async def search(
        self, session_id: str, query: str, limit: int = 0
    ) -> list[Record]:
        needle = query.strip().lower()
        out = [
            item.record
            for item in self._records.get(session_id, [])
            if not needle or needle in item.search
        ]
        out.sort(
            key=lambda record: record.created_at or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        if limit > 0:
            out = out[:limit]
        return out


@dataclass
class ContextAssembler:
    store: Store
    limit: int = 8

    async def assemble(self, session_id: str, query: str) -> list[Record]:
        limit = self.limit if self.limit > 0 else 8
        return await self.store.search(session_id, query, limit)
