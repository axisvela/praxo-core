from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, Protocol, runtime_checkable

from .errors import PraxoError


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


@dataclass
class Event:
    type: str
    session_id: str
    run_id: str = ""
    data: dict[str, Any] = field(default_factory=dict)
    at: datetime = field(default_factory=_utc_now)

    def to_wire(self) -> dict[str, Any]:
        out: dict[str, Any] = {
            "type": self.type,
            "sessionId": self.session_id,
            "at": self.at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        }
        if self.run_id:
            out["runId"] = self.run_id
        if self.data:
            out["data"] = self.data
        return out

    @classmethod
    def from_wire(cls, raw: dict[str, Any]) -> Event:
        at = raw.get("at")
        return cls(
            type=raw.get("type", ""),
            session_id=raw.get("sessionId", ""),
            run_id=raw.get("runId", ""),
            data=raw.get("data") or {},
            at=datetime.fromisoformat(at.replace("Z", "+00:00")) if at else _utc_now(),
        )


@runtime_checkable
class Sink(Protocol):
    async def emit(self, event: Event) -> None: ...


class MultiSink:
    def __init__(self, sinks: list[Sink]) -> None:
        self.sinks = sinks

    async def emit(self, event: Event) -> None:
        for sink in self.sinks:
            if sink is None:
                continue
            try:
                await sink.emit(event)
            except PraxoError:
                raise
            except Exception as exc:
                raise PraxoError(str(exc)) from exc


class FilterSink:
    def __init__(
        self,
        sink: Sink,
        predicate: Callable[[Event], bool] | None = None,
    ) -> None:
        self.sink = sink
        self.predicate = predicate

    async def emit(self, event: Event) -> None:
        if self.sink is None:
            return
        if self.predicate is not None and not self.predicate(event):
            return
        await self.sink.emit(event)
