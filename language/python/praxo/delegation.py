from __future__ import annotations

import asyncio
import itertools
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Protocol, runtime_checkable


class SubagentMode(str, Enum):
    ISOLATED = "isolated"
    FORK = "fork"


class SubagentStatus(str, Enum):
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELED = "canceled"


@dataclass
class SubagentRequest:
    parent_session_id: str
    agent_id: str
    prompt: str
    context: dict[str, Any] = field(default_factory=dict)
    mode: SubagentMode = SubagentMode.ISOLATED
    history: list[Any] = field(default_factory=list)


@dataclass
class SubagentResult:
    task_id: str = ""
    agent_id: str = ""
    output: str = ""
    usage: Any = None


@dataclass
class SubagentTask:
    id: str
    parent_session_id: str
    agent_id: str
    mode: SubagentMode
    status: SubagentStatus
    output: str = ""
    error: str = ""
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@runtime_checkable
class SubagentRunner(Protocol):
    async def run(self, request: SubagentRequest) -> SubagentResult: ...


@runtime_checkable
class ControllableRunner(SubagentRunner, Protocol):
    async def update(self, task_id: str, prompt: str) -> None: ...


class SubagentUpdateUnsupported(RuntimeError):
    pass


def _terminal(status: SubagentStatus) -> bool:
    return status in (
        SubagentStatus.COMPLETED,
        SubagentStatus.FAILED,
        SubagentStatus.CANCELED,
    )


class SubagentManager:
    def __init__(self, runner: SubagentRunner) -> None:
        self.runner = runner
        self._tasks: dict[str, SubagentTask] = {}
        self._jobs: dict[str, asyncio.Task[None]] = {}
        self._events: dict[str, asyncio.Event] = {}
        self._sequence = itertools.count(1)
        self._lock = asyncio.Lock()

    async def launch(self, request: SubagentRequest) -> SubagentTask:
        if self.runner is None:
            raise ValueError("agent: subagent runner is required")
        if not request.parent_session_id or not request.agent_id:
            raise ValueError(
                "agent: subagent parent session and agent id are required"
            )
        task_id = f"subagent-{next(self._sequence)}"
        now = datetime.now(timezone.utc)
        task = SubagentTask(
            id=task_id,
            parent_session_id=request.parent_session_id,
            agent_id=request.agent_id,
            mode=request.mode or SubagentMode.ISOLATED,
            status=SubagentStatus.QUEUED,
            created_at=now,
            updated_at=now,
        )
        async with self._lock:
            self._tasks[task_id] = task
            self._events[task_id] = asyncio.Event()
            self._jobs[task_id] = asyncio.create_task(self._run(task_id, request))
        return self._copy(task)

    def check(self, task_id: str) -> SubagentTask | None:
        task = self._tasks.get(task_id)
        return self._copy(task) if task is not None else None

    async def wait(
        self, task_id: str, timeout: float | None = None
    ) -> SubagentTask:
        task = self._tasks.get(task_id)
        if task is None:
            raise ValueError(f'agent: unknown subagent task "{task_id}"')
        if not _terminal(task.status):
            event = self._events[task_id]
            if timeout is None:
                await event.wait()
            else:
                await asyncio.wait_for(event.wait(), timeout=timeout)
        return self._copy(self._tasks[task_id])

    async def update(self, task_id: str, prompt: str) -> None:
        if not isinstance(self.runner, ControllableRunner):
            raise SubagentUpdateUnsupported(
                "agent: subagent update unsupported"
            )
        task = self._tasks.get(task_id)
        if task is None:
            raise ValueError(f'agent: unknown subagent task "{task_id}"')
        if task.status is not SubagentStatus.RUNNING:
            raise ValueError(
                f'agent: subagent task "{task_id}" is not running'
            )
        await self.runner.update(task_id, prompt)

    async def cancel(self, task_id: str) -> None:
        task = self._tasks.get(task_id)
        if task is None:
            raise ValueError(f'agent: unknown subagent task "{task_id}"')
        if _terminal(task.status):
            return
        job = self._jobs.get(task_id)
        if job is not None:
            job.cancel()
        self._set(task_id, SubagentStatus.CANCELED)

    async def _run(self, task_id: str, request: SubagentRequest) -> None:
        self._set(task_id, SubagentStatus.RUNNING)
        try:
            result = await self.runner.run(request)
        except asyncio.CancelledError:
            self._set(task_id, SubagentStatus.CANCELED)
            raise
        except Exception as error:  # noqa: BLE001 - status carries the failure
            self._set(task_id, SubagentStatus.FAILED, error=str(error))
            return
        self._set(task_id, SubagentStatus.COMPLETED, output=result.output)

    def _set(
        self,
        task_id: str,
        status: SubagentStatus,
        output: str = "",
        error: str = "",
    ) -> None:
        task = self._tasks[task_id]
        task.status = status
        task.output = output
        task.error = error
        task.updated_at = datetime.now(timezone.utc)
        if _terminal(status):
            self._events[task_id].set()

    def _copy(self, task: SubagentTask) -> SubagentTask:
        return SubagentTask(
            id=task.id,
            parent_session_id=task.parent_session_id,
            agent_id=task.agent_id,
            mode=task.mode,
            status=task.status,
            output=task.output,
            error=task.error,
            created_at=task.created_at,
            updated_at=task.updated_at,
        )
