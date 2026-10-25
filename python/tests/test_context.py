from __future__ import annotations

import asyncio
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.context import (
    ContextBudget,
    MaxAgentsMDBytes,
    ModelSummarizer,
    OffloadFunc,
    estimate_tokens,
    load_agents_md,
)
from praxo.model import Message, Response


class ContextTest(unittest.TestCase):
    def test_estimate_tokens(self) -> None:
        messages = [Message(role="user", content="12345678")]
        self.assertEqual(estimate_tokens(messages), 6)

    def test_compact_fits_and_preserves_input(self) -> None:
        messages = [Message(role="system", content="sys")]
        messages.extend(
            Message(role="user", content=f"message {index}")
            for index in range(10)
        )
        original = [(message.role, message.content) for message in messages]
        budget = ContextBudget(max_tokens=30, keep_recent=2)
        out, ok = budget.compact(messages)
        self.assertTrue(ok)
        self.assertLessEqual(estimate_tokens(out), 30)
        self.assertTrue(
            any("context compacted" in message.content for message in out)
        )
        self.assertEqual(out[-1].content, "message 9")
        self.assertEqual(
            [(message.role, message.content) for message in messages],
            original,
        )

    def test_system_prompt_is_truncated(self) -> None:
        messages = [Message(role="system", content="x" * 1000)]
        out, ok = ContextBudget(max_tokens=5).compact(messages)
        self.assertTrue(ok)
        self.assertLessEqual(estimate_tokens(out), 5)

    def test_summarizer_uses_model(self) -> None:
        class SummaryModel:
            async def generate(self, request):
                return Response(
                    message=Message(role="assistant", content="summary")
                )

        messages = [Message(role="system", content="sys")]
        messages.extend(
            Message(role="user", content=f"message {index}")
            for index in range(6)
        )
        budget = ContextBudget(max_tokens=30, keep_recent=2)
        out = asyncio.run(
            ModelSummarizer(SummaryModel()).compact(messages, budget)
        )
        self.assertTrue(
            any("context summary" in message.content for message in out)
        )
        self.assertLessEqual(estimate_tokens(out), 30)

    def test_summarizer_falls_back_on_error(self) -> None:
        class FailingModel:
            async def generate(self, request):
                raise RuntimeError("boom")

        messages = [Message(role="system", content="sys")]
        messages.extend(
            Message(role="user", content=f"message {index}")
            for index in range(6)
        )
        budget = ContextBudget(max_tokens=30, keep_recent=2)
        out = asyncio.run(
            ModelSummarizer(FailingModel()).compact(messages, budget)
        )
        self.assertLessEqual(estimate_tokens(out), 30)

    def test_load_agents_md(self) -> None:
        with tempfile.TemporaryDirectory() as base:
            first = Path(base) / "a.md"
            second = Path(base) / "b.md"
            first.write_text("first", encoding="utf-8")
            second.write_text("second", encoding="utf-8")
            text = load_agents_md([str(first), str(second)])
            self.assertIn(f"## AGENTS.md: {first}", text)
            self.assertIn(f"## AGENTS.md: {second}", text)
            self.assertLess(text.index("first"), text.index("second"))

    def test_load_agents_md_truncates(self) -> None:
        with tempfile.TemporaryDirectory() as base:
            path = Path(base) / "big.md"
            path.write_text("x" * (MaxAgentsMDBytes + 100), encoding="utf-8")
            text = load_agents_md([str(path)])
            self.assertTrue(text.endswith("[truncated]"))
            self.assertLessEqual(
                len(text.encode("utf-8")), MaxAgentsMDBytes + len("\n[truncated]")
            )

    def test_offload_func(self) -> None:
        calls = []

        async def offload(tool, call_id, data):
            calls.append((tool, call_id, data))
            return "[offloaded]"

        func = OffloadFunc(offload)
        result = asyncio.run(func.offload("echo", "c1", b"data"))
        self.assertEqual(result, "[offloaded]")
        self.assertEqual(calls, [("echo", "c1", b"data")])


if __name__ == "__main__":
    unittest.main()
