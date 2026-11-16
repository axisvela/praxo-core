import asyncio
import sys
from typing import TextIO

from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.model import Message, Request, Response, ToolCall
from praxo.policy import Action, Decision, FuncHook
from praxo.tool import Registry


class FixtureModel:
    def __init__(self, tool_name: str, arguments: dict, final: str):
        self.tool_name = tool_name
        self.arguments = arguments
        self.final = final
        self.calls = 0

    async def generate(self, request: Request) -> Response:
        self.calls += 1
        if request.messages[-1].role == "tool":
            return Response(
                message=Message(role="assistant", content=self.final)
            )
        return Response(
            message=Message(
                role="assistant",
                tool_calls=[
                    ToolCall(
                        id=f"call-{self.calls}",
                        name=self.tool_name,
                        arguments=self.arguments,
                    )
                ],
            )
        )


class RecordTool:
    name = "record"
    description = "Record a child result in an in-memory counter."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["target"],
        "properties": {"target": {"type": "string"}},
    }

    def __init__(self) -> None:
        self.calls = 0

    async def invoke(self, args: dict):
        self.calls += 1
        return f"recorded:{args.get('target', '')}"


class ParentOnlyTool:
    name = "parent_only"
    description = "A tool that must remain outside the child scope."
    risk = "write"
    parameters = {"type": "object", "properties": {}}

    def __init__(self) -> None:
        self.calls = 0

    async def invoke(self, _args: dict):
        self.calls += 1
        return "parent-effect"


def build_child(record: RecordTool) -> Agent:
    tools = Registry()
    tools.register(record)

    def authorize(action: Action) -> Decision:
        if action.kind == "model.generate":
            return Decision(True)
        if action.kind == "tool.invoke":
            return Decision(
                action.tool_name == "record",
                "child may only record",
            )
        return Decision(False, "unsupported action")

    return Agent(
        AgentOptions(
            model=FixtureModel(
                "record",
                {"target": "delegated"},
                "child-recorded",
            ),
            tools=tools,
            max_steps=3,
            allowed_tools=["record"],
            policy=FuncHook(authorize),
            require_policy=True,
            require_tool_scope=True,
        )
    )


def build_parent(record: RecordTool) -> Agent:
    tools = Registry()

    class DelegateTool:
        name = "delegate"
        description = "Run the child agent with a restricted tool scope."
        risk = "write"
        parameters = {
            "type": "object",
            "required": ["task"],
            "properties": {"task": {"type": "string"}},
        }

        async def invoke(self, args: dict):
            child = build_child(record)
            result = await child.run(
                Session(id="advanced-delegation-child"),
                str(args.get("task", "")),
            )
            return {"output": result.output, "effects": record.calls}

    tools.register(DelegateTool())
    tools.register(ParentOnlyTool())

    def authorize(action: Action) -> Decision:
        if action.kind == "model.generate":
            return Decision(True)
        if action.kind == "tool.invoke":
            return Decision(
                action.tool_name in {"delegate", "parent_only"},
                "parent may delegate but not record",
            )
        return Decision(False, "unsupported action")

    return Agent(
        AgentOptions(
            model=FixtureModel(
                "delegate",
                {"task": "record the delegated result"},
                "parent-done",
            ),
            tools=tools,
            max_steps=3,
            allowed_tools=["delegate", "parent_only"],
            policy=FuncHook(authorize),
            require_policy=True,
            require_tool_scope=True,
        )
    )


async def run(output: TextIO) -> None:
    record = RecordTool()
    parent = build_parent(record)
    result = await parent.run(
        Session(id="advanced-delegation-parent"),
        "Delegate the record operation to the child agent.",
    )
    if result.output != "parent-done" or record.calls != 1:
        raise RuntimeError(
            f"delegation failed: output={result.output!r} effects={record.calls}"
        )
    print("delegation: child recorded; parent scope enforced", file=output)

    direct = Registry()
    direct.register(record)
    try:
        denied = Agent(
            AgentOptions(
                model=FixtureModel("record", {"target": "parent"}, "unexpected"),
                tools=direct,
                max_steps=3,
                allowed_tools=["record"],
                policy=FuncHook(
                    lambda action: Decision(
                        action.kind == "model.generate",
                        "parent may not record",
                    )
                ),
                require_policy=True,
                require_tool_scope=True,
            )
        )
        await denied.run(
            Session(id="advanced-delegation-direct"),
            "Record directly.",
        )
    except PolicyDeniedError:
        if record.calls != 1:
            raise RuntimeError("denied parent call produced a child effect")
    else:
        raise RuntimeError("parent recorded outside the delegated scope")
    print("deny: parent record blocked; child effect unchanged", file=output)


if __name__ == "__main__":
    asyncio.run(run(sys.stdout))
