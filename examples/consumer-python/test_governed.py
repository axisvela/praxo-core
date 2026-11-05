import unittest

from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.hitl import INTERRUPT_EDIT, InterruptDecision
from praxo.middleware import Middleware
from praxo.policy import Decision, FuncHook
from praxo.tool import Registry

from starter import FixtureModel, RecordTool


def governed_agent(target, hook, allowed, middleware=None, interrupt_on=None, decision=None):
    if hook is None:
        raise ValueError("governed: mandatory policy is missing")
    if not allowed:
        raise ValueError("governed: explicit tool scope is required")
    tool = RecordTool()
    tools = Registry()
    tools.register(tool)
    agent = Agent(AgentOptions(
        model=FixtureModel(target),
        tools=tools,
        max_steps=3,
        allowed_tools=list(allowed),
        policy=hook,
        middleware=list(middleware or []),
        interrupt_on=set(interrupt_on or []),
        on_interrupt_decision=decision,
    ))
    return agent, tool


def public_only(checked):
    def authorize(action):
        if action.kind == "model.generate":
            return Decision(True)
        if action.kind == "tool.invoke":
            target = action.arguments.get("target")
            checked.append(target)
            return Decision(target == "public", "only the public target is permitted")
        return Decision(False, "unsupported action")
    return FuncHook(authorize)


class GovernedAcceptanceTests(unittest.IsolatedAsyncioTestCase):
    async def test_missing_policy_is_rejected(self):
        with self.assertRaises(ValueError):
            governed_agent("public", None, ["record"])

    async def test_empty_tool_scope_is_rejected(self):
        with self.assertRaises(ValueError):
            governed_agent("public", public_only([]), [])

    async def test_final_arguments_are_reauthorized(self):
        checked = []

        def mutate(call):
            call.call.arguments = {"target": "private"}

        agent, tool = governed_agent(
            "public", public_only(checked), ["record"],
            middleware=[Middleware(before_tool=mutate)],
        )
        with self.assertRaises(PolicyDeniedError):
            await agent.run(Session(id="governed-final-args"), "record")
        self.assertEqual(tool.calls, 0)
        self.assertEqual(checked, ["public", "private"])

    async def test_approval_edit_is_reauthorized(self):
        checked = []
        agent, tool = governed_agent(
            "public", public_only(checked), ["record"],
            interrupt_on=["record"],
            decision=lambda interrupt: InterruptDecision(
                action=INTERRUPT_EDIT, arguments={"target": "private"},
            ),
        )
        with self.assertRaises(PolicyDeniedError):
            await agent.run(Session(id="governed-approval-edit"), "record")
        self.assertEqual(tool.calls, 0)
        self.assertEqual(checked, ["public", "private"])

    async def test_policy_error_fails_closed(self):
        def fail(action):
            if action.kind == "tool.invoke":
                raise RuntimeError("policy service unavailable")
            return Decision(True)

        agent, tool = governed_agent("public", FuncHook(fail), ["record"])
        with self.assertRaises(RuntimeError):
            await agent.run(Session(id="governed-policy-error"), "record")
        self.assertEqual(tool.calls, 0)


if __name__ == "__main__":
    unittest.main()
