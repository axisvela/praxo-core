from __future__ import annotations

import asyncio
import sys
import threading
import unittest
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from delegation import FixtureModel, ParentOnlyTool, RecordTool
from praxo import (
    Action,
    Agent,
    AgentOptions,
    Decision,
    FuncHook,
    Middleware,
    Registry,
    Session,
)
from praxo.errors import PolicyDeniedError


class BudgetExhausted(Exception):
    pass


class DelegationError(Exception):
    pass


class SharedBudget:
    def __init__(self, remaining: int) -> None:
        self.remaining = remaining
        self._lock = threading.Lock()

    def available(self) -> bool:
        with self._lock:
            return self.remaining > 0

    def take(self) -> bool:
        with self._lock:
            if self.remaining <= 0:
                return False
            self.remaining -= 1
            return True


class ComposedPolicy:
    def __init__(self, hooks: list[Any]) -> None:
        self.hooks = [hook for hook in hooks if hook is not None]

    async def authorize(self, action: Action) -> Decision:
        for hook in self.hooks:
            decision = await hook.authorize(action)
            if not decision.allowed:
                return decision
        return Decision(True, "delegation policy chain allowed")


class BudgetedTool:
    def __init__(self, inner: Any, budget: SharedBudget) -> None:
        self.inner = inner
        self.budget = budget
        self.name = inner.name
        self.description = inner.description
        self.risk = getattr(inner, "risk", None)
        self.parameters = getattr(inner, "parameters", None)

    async def invoke(self, args: dict[str, Any]) -> Any:
        if not self.budget.take():
            raise BudgetExhausted("delegation budget exhausted")
        return await self.inner.invoke(args)


@dataclass
class Authority:
    allowed: frozenset[str]
    delegable: frozenset[str]
    max_depth: int
    max_children: int
    depth: int = 0
    budget: SharedBudget = field(default_factory=lambda: SharedBudget(1))
    policy: Any = None


class ChildScope:
    def __init__(self, authority: Authority, release: Any) -> None:
        self.authority = authority
        self.release = release

    async def run(
        self,
        model: Any,
        tools: Registry,
        prompt: str,
        middleware: list[Middleware] | None = None,
    ) -> Any:
        scoped = Registry()
        for name in sorted(self.authority.allowed):
            scoped.register(
                BudgetedTool(tools.get(name), self.authority.budget)
            )
        agent = Agent(
            AgentOptions(
                model=model,
                tools=scoped,
                max_steps=3,
                allowed_tools=sorted(self.authority.allowed),
                policy=self.authority.policy,
                middleware=list(middleware or []),
                require_policy=True,
                require_tool_scope=True,
            )
        )
        return await agent.run(
            Session(id="governed-delegation-child"), prompt
        )


class Governor:
    def __init__(self, authority: Authority) -> None:
        self.authority = authority
        self._active = 0
        self._lock = threading.Lock()

    def delegate(
        self,
        allowed: list[str],
        delegable: list[str] | None = None,
        policy: Any = None,
    ) -> ChildScope:
        if self.authority.depth + 1 > self.authority.max_depth:
            raise DelegationError("delegation depth exceeded")
        if not allowed:
            raise DelegationError("delegation tool scope is empty")
        allowed_set = frozenset(allowed)
        if not allowed_set <= self.authority.delegable:
            raise DelegationError("delegation scope exceeds parent")
        if not allowed_set <= self.authority.allowed:
            raise DelegationError("delegation scope is not allowed")
        delegable_set = frozenset(delegable or [])
        if not delegable_set <= self.authority.delegable:
            raise DelegationError("child delegable scope exceeds parent")
        if not self.authority.budget.available():
            raise BudgetExhausted("delegation budget exhausted")
        with self._lock:
            if self._active >= self.authority.max_children:
                raise DelegationError("delegation child limit exceeded")
            self._active += 1

        def release() -> None:
            with self._lock:
                self._active -= 1

        return ChildScope(
            Authority(
                allowed=allowed_set,
                delegable=delegable_set,
                max_depth=self.authority.max_depth,
                max_children=self.authority.max_children,
                depth=self.authority.depth + 1,
                budget=self.authority.budget,
                policy=ComposedPolicy([self.authority.policy, policy]),
            ),
            release,
        )


def allow_all(_action: Action) -> Decision:
    return Decision(True)


def record_policy(action: Action) -> Decision:
    if action.kind != "tool.invoke":
        return Decision(True)
    if action.tool_name != "record":
        return Decision(False, "child may only record")
    if action.arguments.get("target") == "blocked":
        return Decision(False, "blocked target")
    return Decision(True)


class GovernanceTest(unittest.IsolatedAsyncioTestCase):
    async def test_rejects_scope_escalation(self) -> None:
        record = RecordTool()
        parent_only = ParentOnlyTool()
        tools = Registry()
        tools.register(record)
        tools.register(parent_only)
        governor = Governor(
            Authority(
                allowed=frozenset({"record", "parent_only"}),
                delegable=frozenset({"record"}),
                max_depth=1,
                max_children=2,
                budget=SharedBudget(2),
                policy=FuncHook(allow_all),
            )
        )
        with self.assertRaises(DelegationError):
            governor.delegate(["parent_only"])
        self.assertEqual(record.calls, 0)
        self.assertEqual(parent_only.calls, 0)
        child = governor.delegate(["record"], policy=FuncHook(record_policy))
        child.release()

    async def test_rejects_excess_depth(self) -> None:
        governor = Governor(
            Authority(
                allowed=frozenset({"record"}),
                delegable=frozenset({"record"}),
                max_depth=1,
                max_children=1,
                budget=SharedBudget(2),
                policy=FuncHook(allow_all),
            )
        )
        child = governor.delegate(["record"])
        child.authority.delegable = frozenset({"record"})
        grand = Governor(child.authority)
        with self.assertRaises(DelegationError):
            grand.delegate(["record"])
        child.release()

    async def test_rejects_excess_children(self) -> None:
        governor = Governor(
            Authority(
                allowed=frozenset({"record"}),
                delegable=frozenset({"record"}),
                max_depth=1,
                max_children=1,
                budget=SharedBudget(2),
                policy=FuncHook(allow_all),
            )
        )
        first = governor.delegate(["record"])
        with self.assertRaises(DelegationError):
            governor.delegate(["record"])
        first.release()
        second = governor.delegate(["record"])
        second.release()

    async def test_shares_sibling_budget(self) -> None:
        record = RecordTool()
        tools = Registry()
        tools.register(record)
        governor = Governor(
            Authority(
                allowed=frozenset({"record"}),
                delegable=frozenset({"record"}),
                max_depth=1,
                max_children=2,
                budget=SharedBudget(1),
                policy=FuncHook(allow_all),
            )
        )
        first = governor.delegate(["record"], policy=FuncHook(record_policy))
        second = governor.delegate(["record"], policy=FuncHook(record_policy))
        try:
            await first.run(
                FixtureModel("record", {"target": "first"}, "first-done"),
                tools,
                "record once",
            )
            with self.assertRaises(BudgetExhausted):
                await second.run(
                    FixtureModel(
                        "record", {"target": "second"}, "second-done"
                    ),
                    tools,
                    "record twice",
                )
        finally:
            first.release()
            second.release()
        self.assertEqual(record.calls, 1)

    async def test_cancels_child_without_effects(self) -> None:
        started = asyncio.Event()
        effects = 0

        class SlowTool:
            name = "slow"
            description = "wait for cancellation"
            risk = "write"
            parameters = {"type": "object", "properties": {}}

            async def invoke(self, _args: dict[str, Any]) -> Any:
                nonlocal effects
                started.set()
                await asyncio.Event().wait()
                effects += 1
                return "unexpected"

        tools = Registry()
        tools.register(SlowTool())
        governor = Governor(
            Authority(
                allowed=frozenset({"slow"}),
                delegable=frozenset({"slow"}),
                max_depth=1,
                max_children=1,
                budget=SharedBudget(1),
                policy=FuncHook(allow_all),
            )
        )
        child = governor.delegate(["slow"])
        try:
            task = asyncio.create_task(
                child.run(
                    FixtureModel("slow", {}, "slow-done"),
                    tools,
                    "wait",
                )
            )
            await started.wait()
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
        finally:
            child.release()
        self.assertEqual(effects, 0)

    async def test_reauthorizes_final_arguments(self) -> None:
        record = RecordTool()
        tools = Registry()
        tools.register(record)
        governor = Governor(
            Authority(
                allowed=frozenset({"record"}),
                delegable=frozenset({"record"}),
                max_depth=1,
                max_children=1,
                budget=SharedBudget(1),
                policy=FuncHook(allow_all),
            )
        )
        child = governor.delegate(
            ["record"], policy=FuncHook(record_policy)
        )

        async def edit(call: Any) -> None:
            call.call.arguments["target"] = "blocked"

        try:
            with self.assertRaises(PolicyDeniedError):
                await child.run(
                    FixtureModel(
                        "record", {"target": "safe"}, "unexpected"
                    ),
                    tools,
                    "record safely",
                    middleware=[Middleware(before_tool=edit)],
                )
        finally:
            child.release()
        self.assertEqual(record.calls, 0)


if __name__ == "__main__":
    unittest.main()
