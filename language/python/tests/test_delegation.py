from __future__ import annotations

import asyncio
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.delegation import (
    SubagentManager,
    SubagentMode,
    SubagentRequest,
    SubagentResult,
    SubagentStatus,
    SubagentUpdateUnsupported,
)


class Runner:
    def __init__(self) -> None:
        self.requests: list[SubagentRequest] = []

    async def run(self, request: SubagentRequest) -> SubagentResult:
        self.requests.append(request)
        return SubagentResult(output="done")


class FailingRunner:
    async def run(self, request: SubagentRequest) -> SubagentResult:
        raise RuntimeError("boom")


class BlockingRunner:
    def __init__(self) -> None:
        self.started = asyncio.Event()
        self.release = asyncio.Event()

    async def run(self, request: SubagentRequest) -> SubagentResult:
        self.started.set()
        await self.release.wait()
        return SubagentResult(output="released")


class ControllableBlockingRunner(BlockingRunner):
    def __init__(self) -> None:
        super().__init__()
        self.updates: list[tuple[str, str]] = []

    async def update(self, task_id: str, prompt: str) -> None:
        self.updates.append((task_id, prompt))


def request() -> SubagentRequest:
    return SubagentRequest(
        parent_session_id="parent",
        agent_id="child",
        prompt="do work",
        mode=SubagentMode.FORK,
    )


class DelegationTest(unittest.IsolatedAsyncioTestCase):
    async def test_launch_and_wait(self) -> None:
        runner = Runner()
        manager = SubagentManager(runner)
        task = await manager.launch(request())
        self.assertEqual(task.parent_session_id, "parent")
        self.assertEqual(task.agent_id, "child")
        self.assertEqual(task.mode, SubagentMode.FORK)
        final = await manager.wait(task.id, timeout=2)
        self.assertEqual(final.status, SubagentStatus.COMPLETED)
        self.assertEqual(final.output, "done")
        self.assertEqual(len(runner.requests), 1)

    async def test_failure_is_reported(self) -> None:
        manager = SubagentManager(FailingRunner())
        task = await manager.launch(request())
        final = await manager.wait(task.id, timeout=2)
        self.assertEqual(final.status, SubagentStatus.FAILED)
        self.assertIn("boom", final.error)

    async def test_cancel(self) -> None:
        runner = BlockingRunner()
        manager = SubagentManager(runner)
        task = await manager.launch(request())
        await runner.started.wait()
        await manager.cancel(task.id)
        final = await manager.wait(task.id, timeout=2)
        self.assertEqual(final.status, SubagentStatus.CANCELED)

    async def test_update(self) -> None:
        runner = ControllableBlockingRunner()
        manager = SubagentManager(runner)
        task = await manager.launch(request())
        await runner.started.wait()
        await manager.update(task.id, "steer")
        self.assertEqual(runner.updates, [(task.id, "steer")])
        runner.release.set()
        final = await manager.wait(task.id, timeout=2)
        self.assertEqual(final.status, SubagentStatus.COMPLETED)

    async def test_update_unsupported(self) -> None:
        runner = BlockingRunner()
        manager = SubagentManager(runner)
        task = await manager.launch(request())
        await runner.started.wait()
        with self.assertRaises(SubagentUpdateUnsupported):
            await manager.update(task.id, "steer")
        runner.release.set()
        await manager.wait(task.id, timeout=2)

    async def test_unknown_task(self) -> None:
        manager = SubagentManager(Runner())
        self.assertIsNone(manager.check("missing"))
        with self.assertRaises(ValueError):
            await manager.wait("missing", timeout=0.1)
