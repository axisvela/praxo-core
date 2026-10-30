from __future__ import annotations

import asyncio
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.agent import Agent, AgentOptions, Session
from praxo.event import Event
from praxo.middleware import Middleware
from praxo.model import Message, Response


class ScriptModel:
    def __init__(self, error=None):
        self.error = error

    async def generate(self, request):
        if self.error is not None:
            raise self.error
        return Response(message=Message(role="assistant", content="done"))


class RecordingSink:
    def __init__(self):
        self.events: list[Event] = []

    async def emit(self, event: Event) -> None:
        self.events.append(event)


class LifecycleTest(unittest.IsolatedAsyncioTestCase):
    async def test_startup_failure_cleans_entered_and_emits_no_events(self) -> None:
        calls: list[str] = []
        sink = RecordingSink()
        first = Middleware(
            before_run=lambda state: calls.append("first.before"),
            after_run=lambda result, error: calls.append(
                f"first.after:{type(error).__name__}"
            ),
        )

        def fail_before(state):
            calls.append("second.before")
            raise RuntimeError("startup failed")

        second = Middleware(
            before_run=fail_before,
            after_run=lambda result, error: calls.append("second.after"),
        )
        third = Middleware(
            before_run=lambda state: calls.append("third.before"),
            after_run=lambda result, error: calls.append("third.after"),
        )
        agent = Agent(
            AgentOptions(
                model=ScriptModel(),
                events=sink,
                middleware=[first, second, third],
            )
        )
        with self.assertRaisesRegex(RuntimeError, "startup failed"):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(
            calls,
            [
                "first.before",
                "second.before",
                "first.after:RuntimeError",
                "second.after",
            ],
        )
        self.assertEqual(sink.events, [])

    async def test_cleanup_continues_and_preserves_run_error(self) -> None:
        calls: list[str] = []
        def fail_cleanup(result, error):
            calls.append("first.after")
            raise RuntimeError("cleanup failed")

        first = Middleware(after_run=fail_cleanup)
        second = Middleware(
            after_run=lambda result, error: calls.append("second.after")
        )
        agent = Agent(
            AgentOptions(
                model=ScriptModel(error=RuntimeError("run failed")),
                middleware=[first, second],
            )
        )
        with self.assertRaisesRegex(RuntimeError, "run failed"):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(calls, ["first.after", "second.after"])

    async def test_cleanup_error_after_success_fails_closed(self) -> None:
        calls: list[str] = []
        sink = RecordingSink()
        def fail_cleanup(result, error):
            calls.append("first.after")
            raise RuntimeError("cleanup failed")

        first = Middleware(after_run=fail_cleanup)
        second = Middleware(
            after_run=lambda result, error: calls.append("second.after")
        )
        agent = Agent(
            AgentOptions(
                model=ScriptModel(),
                events=sink,
                middleware=[first, second],
            )
        )
        with self.assertRaisesRegex(RuntimeError, "cleanup failed"):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(calls, ["first.after", "second.after"])
        self.assertEqual(
            [event.type for event in sink.events],
            ["run.started", "run.failed"],
        )

    async def test_cancellation_runs_after_run_and_emits_failed(self) -> None:
        started = asyncio.Event()
        calls: list[str] = []
        sink = RecordingSink()

        class WaitModel:
            async def generate(self, request):
                started.set()
                await asyncio.Event().wait()

        middleware = Middleware(
            after_run=lambda result, error: calls.append(
                f"after:{type(error).__name__}"
            )
        )
        agent = Agent(
            AgentOptions(
                model=WaitModel(),
                events=sink,
                middleware=[middleware],
            )
        )
        task = asyncio.create_task(agent.run(Session(id="s1"), "go"))
        await started.wait()
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task
        self.assertEqual(calls, ["after:CancelledError"])
        self.assertEqual(
            [event.type for event in sink.events],
            ["run.started", "run.failed"],
        )


if __name__ == "__main__":
    unittest.main()
