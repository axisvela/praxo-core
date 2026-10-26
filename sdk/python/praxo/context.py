from __future__ import annotations

import copy
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Awaitable, Callable, Protocol, runtime_checkable

from .errors import ContextBudgetError
from .model import Message, Model, Request, ROLE_SYSTEM, ROLE_TOOL

MaxAgentsMDBytes = 64 << 10

COMPACT_MARKER_PREFIX = "[context compacted:"
SUMMARY_MARKER_PREFIX = "[context summary:"

DEFAULT_SUMMARY_PROMPT = (
    "Summarize the conversation so far. Preserve decisions, open tasks, "
    "tool results, constraints, and user preferences. Be concise."
)


def _byte_len(value: str | None) -> int:
    return len((value or "").encode("utf-8"))


def estimate_tokens(messages: list[Message]) -> int:
    total = 0
    for message in messages:
        total += 4 + _byte_len(message.content) // 4 + _byte_len(message.tool_id) // 4
        for block in message.content_blocks:
            total += (
                4
                + _byte_len(block.text) // 4
                + _byte_len(block.image_url) // 4
                + _byte_len(block.data) // 4
            )
        for call in message.tool_calls:
            total += 4 + _byte_len(call.name) // 4
            raw = json.dumps(
                call.arguments,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            total += _byte_len(raw) // 4
    return total


def truncate_to_tokens(value: str, tokens: int) -> str:
    if tokens <= 0:
        return ""
    limit = tokens * 4
    raw = value.encode("utf-8")
    if len(raw) <= limit:
        return value
    if limit <= 16:
        return raw[:limit].decode("utf-8", errors="ignore")
    return raw[: limit - 16].decode("utf-8", errors="ignore") + "\n[truncated]"


@dataclass
class ContextBudget:
    max_tokens: int = 0
    keep_recent: int = 0

    def compact(self, messages: list[Message]) -> tuple[list[Message], bool]:
        if self.max_tokens <= 0:
            return messages, True
        if estimate_tokens(messages) <= self.max_tokens:
            return messages, True

        system: list[Message] = []
        rest: list[Message] = []
        for message in messages:
            if message.role == ROLE_SYSTEM:
                if message.content.startswith(COMPACT_MARKER_PREFIX):
                    continue
                system.append(copy.deepcopy(message))
                continue
            rest.append(copy.deepcopy(message))

        if estimate_tokens(system) > self.max_tokens:
            if not system:
                return [], False
            system = [system[0]]
            system[0].content = truncate_to_tokens(
                system[0].content, self.max_tokens - 4
            )
            if estimate_tokens(system) > self.max_tokens:
                return [], False

        keep = self.keep_recent if self.keep_recent > 0 else 4
        start = max(0, len(rest) - keep)
        while start > 0 and rest[start].role == ROLE_TOOL:
            start -= 1

        marker = Message(
            role=ROLE_SYSTEM,
            content=f"{COMPACT_MARKER_PREFIX} {start} older messages omitted]",
        )
        kept = rest[start:]
        out = _build_compacted(system, marker, start > 0, kept)
        while estimate_tokens(out) > self.max_tokens and len(kept) > 1:
            if kept[1].role == ROLE_TOOL:
                break
            kept = kept[1:]
            out = _build_compacted(system, marker, start > 0, kept)
        if estimate_tokens(out) > self.max_tokens:
            return [], False
        return out, True


def _build_compacted(
    system: list[Message],
    marker: Message,
    include_marker: bool,
    kept: list[Message],
) -> list[Message]:
    out = list(system)
    if include_marker:
        out.append(marker)
    out.extend(kept)
    return out


@runtime_checkable
class ContextCompactor(Protocol):
    async def compact(
        self, messages: list[Message], budget: ContextBudget
    ) -> list[Message]: ...


class ModelSummarizer:
    def __init__(
        self,
        model: Model | None,
        prompt: str = "",
        max_summary_tokens: int = 0,
    ) -> None:
        self.model = model
        self.prompt = prompt
        self.max_summary_tokens = max_summary_tokens

    async def compact(
        self, messages: list[Message], budget: ContextBudget
    ) -> list[Message]:
        if budget.max_tokens <= 0 or estimate_tokens(messages) <= budget.max_tokens:
            return messages
        if self.model is None:
            return _fit_budget(messages, budget)

        system: list[Message] = []
        rest: list[Message] = []
        for message in messages:
            if message.role == ROLE_SYSTEM:
                if message.content.startswith(
                    COMPACT_MARKER_PREFIX
                ) or message.content.startswith(SUMMARY_MARKER_PREFIX):
                    continue
                system.append(copy.deepcopy(message))
                continue
            rest.append(copy.deepcopy(message))

        keep = budget.keep_recent if budget.keep_recent > 0 else 4
        start = max(0, len(rest) - keep)
        while start > 0 and rest[start].role == ROLE_TOOL:
            start -= 1
        if start == 0:
            return _fit_budget(messages, budget)

        summary = await self._summarize(rest[:start])
        if not summary.strip():
            return _fit_budget(messages, budget)
        max_summary = (
            self.max_summary_tokens
            if self.max_summary_tokens > 0
            else budget.max_tokens // 4
        )
        summary = truncate_to_tokens(summary.strip(), max_summary)
        out = list(system)
        out.append(
            Message(
                role=ROLE_SYSTEM,
                content=f"{SUMMARY_MARKER_PREFIX} {summary}]",
            )
        )
        out.extend(rest[start:])
        return _fit_budget(out, budget)

    async def _summarize(self, messages: list[Message]) -> str:
        prompt = self.prompt.strip() or DEFAULT_SUMMARY_PROMPT
        request = Request(
            messages=[Message(role=ROLE_SYSTEM, content=prompt), *messages]
        )
        try:
            response = await self.model.generate(request)
        except Exception:
            return ""
        return response.message.content


def _fit_budget(
    messages: list[Message], budget: ContextBudget
) -> list[Message]:
    out, ok = budget.compact(messages)
    if not ok:
        raise ContextBudgetError("agent: context budget exceeded")
    return out


@runtime_checkable
class Offloader(Protocol):
    async def offload(
        self, tool_name: str, tool_call_id: str, data: bytes
    ) -> str: ...


class OffloadFunc:
    def __init__(
        self,
        fn: Callable[[str, str, bytes], Awaitable[str] | str],
    ) -> None:
        self.fn = fn

    async def offload(
        self, tool_name: str, tool_call_id: str, data: bytes
    ) -> str:
        result = self.fn(tool_name, tool_call_id, data)
        if hasattr(result, "__await__"):
            return await result
        return result


def load_agents_md(paths: list[str] | tuple[str, ...]) -> str:
    chunks: list[str] = []
    used = 0
    for raw_path in paths:
        if not raw_path.strip():
            continue
        text = Path(raw_path).read_text(encoding="utf-8").strip()
        if not text:
            continue
        header = f"## AGENTS.md: {raw_path}\n"
        chunk = header + text
        size = _byte_len(chunk)
        if used + size > MaxAgentsMDBytes:
            remaining = MaxAgentsMDBytes - used
            if remaining <= _byte_len(header):
                break
            truncated = chunk.encode("utf-8")[:remaining].decode(
                "utf-8", errors="ignore"
            )
            chunks.append(truncated + "\n[truncated]")
            break
        chunks.append(chunk)
        used += size
    return "\n\n".join(chunks)
