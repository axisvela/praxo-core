import asyncio
import sys
from typing import TextIO

from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.model import Message, Request, Response, ToolCall
from praxo.policy import Action, Decision, FuncHook
from praxo.tool import Registry


class FixtureModel:
    def __init__(self, target: str):
        self.target = target

    async def generate(self, request: Request) -> Response:
        if request.messages[-1].role == "tool":
            return Response(message=Message(role="assistant", content="recorded"))
        return Response(message=Message(
            role="assistant",
            tool_calls=[ToolCall(id="record-1", name="record", arguments={"target": self.target})],
        ))


class RecordTool:
    name = "record"
    description = "Record a target in an in-memory counter."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["target"],
        "properties": {"target": {"type": "string"}},
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return "recorded"


def build_agent(target: str) -> tuple[Agent, RecordTool]:
    impl = RecordTool()
    tools = Registry()
    tools.register(impl)

    def authorize(action: Action) -> Decision:
        if action.kind == "model.generate":
            return Decision(allowed=True)
        if action.kind == "tool.invoke":
            return Decision(
                allowed=action.tool_name == "record" and action.arguments.get("target") == "public",
                reason="only the public target is permitted",
            )
        return Decision(allowed=False, reason="unsupported action")

    return Agent(AgentOptions(
        model=FixtureModel(target), tools=tools, max_steps=3,
        allowed_tools=["record"], policy=FuncHook(authorize),
    )), impl


async def run(output: TextIO) -> None:
    agent, impl = build_agent("public")
    result = await agent.run(Session(id="starter-public"), "Record the requested target.")
    if result.output != "recorded" or impl.calls != 1:
        raise RuntimeError(f"allow verification failed: output={result.output!r} effects={impl.calls}")
    print("allow: recorded; effects=1", file=output)

    agent, impl = build_agent("private")
    try:
        await agent.run(Session(id="starter-private"), "Record the requested target.")
    except PolicyDeniedError:
        if impl.calls != 0:
            raise RuntimeError(f"denied call produced effects={impl.calls}")
    else:
        raise RuntimeError("private target was not denied")
    print("deny: policy rejected; effects=0", file=output)


if __name__ == "__main__":
    asyncio.run(run(sys.stdout))
