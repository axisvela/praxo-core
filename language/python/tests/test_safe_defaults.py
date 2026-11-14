import unittest

from praxo.agent import Agent, AgentOptions
from praxo.model import Message, Response


class EchoModel:
    async def generate(self, request):
        return Response(message=Message(role="assistant", content="ok"))


class SafeDefaultsTests(unittest.TestCase):
    def test_require_policy_rejects_missing_policy(self):
        with self.assertRaisesRegex(ValueError, "require policy"):
            Agent(AgentOptions(model=EchoModel(), require_policy=True))

    def test_require_tool_scope_rejects_empty_scope(self):
        with self.assertRaisesRegex(ValueError, "require tool scope"):
            Agent(AgentOptions(model=EchoModel(), require_tool_scope=True))

    def test_safe_defaults_accept_explicit_configuration(self):
        agent = Agent(
            AgentOptions(
                model=EchoModel(),
                policy=lambda action: type("Decision", (), {"allowed": True})(),
                allowed_tools=["echo"],
                require_policy=True,
                require_tool_scope=True,
            )
        )
        self.assertTrue(agent.options.require_policy)
        self.assertTrue(agent.options.require_tool_scope)


if __name__ == "__main__":
    unittest.main()
