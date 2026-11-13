from __future__ import annotations

from dataclasses import dataclass, field
from typing import Awaitable, Callable, Protocol, runtime_checkable


@dataclass
class Document:
    id: str
    content: str
    metadata: dict[str, str] = field(default_factory=dict)
    score: float = 0.0

    def to_wire(self) -> dict[str, object]:
        out: dict[str, object] = {"id": self.id, "content": self.content}
        if self.metadata:
            out["metadata"] = dict(self.metadata)
        if self.score:
            out["score"] = self.score
        return out


@runtime_checkable
class Retriever(Protocol):
    async def retrieve(self, query: str, limit: int) -> list[Document]: ...


class FuncRetriever:
    def __init__(
        self,
        retrieve: Callable[[str, int], Awaitable[list[Document]]],
    ) -> None:
        self._retrieve = retrieve

    async def retrieve(self, query: str, limit: int) -> list[Document]:
        return await self._retrieve(query, limit)
