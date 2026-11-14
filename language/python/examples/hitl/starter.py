import asyncio
import sys
from pathlib import Path
from typing import TextIO

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.hitl import INTERRUPT_APPROVE, INTERRUPT_EDIT, InterruptDecision
from praxo.model import Message, Request, Response, ToolCall
from praxo.policy import Action, Decision, FuncHook
from praxo.tool import Registry


class FixtureModel:
    async def generate(self, request: Request) -> Response:
        last = request.messages[-1]
        if last.role == "tool":
            return Response(message=Message(role="assistant", content="done"))
        return Response(message=Message(
            role="assistant",
            tool_calls=[ToolCall(
                id="write-note-1",
                name="write_note",
                arguments={"text": "hello", "visibility": "public"},
            )],
        ))


class WriteNoteTool:
    name = "write_note"
    description = "Write a short note with the requested visibility."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["text", "visibility"],
        "properties": {
            "text": {"type": "string"},
            "visibility": {"type": "string", "enum": ["public", "private"]},
        },
    }

    def __init__(self):
        self.notes: list[str] = []

    async def invoke(self, args):
        self.notes.append(args["text"])
        return "written"


def allow_public(action: Action) -> Decision:
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind == "tool.invoke":
        return Decision(
            allowed=action.tool_name == "write_note"
            and action.arguments.get("visibility") == "public",
            reason="only public notes are permitted",
        )
    return Decision(allowed=False, reason="unsupported action")


def build_agent(decision: InterruptDecision) -> tuple[Agent, WriteNoteTool]:
    tool = WriteNoteTool()
    tools = Registry()
    tools.register(tool)
    agent = Agent(AgentOptions(
        model=FixtureModel(),
        tools=tools,
        max_steps=3,
        allowed_tools=["write_note"],
        policy=FuncHook(allow_public),
        interrupt_on={"write_note"},
        on_interrupt_decision=lambda _interrupt: decision,
    ))
    return agent, tool


async def run(output: TextIO) -> None:
    agent, tool = build_agent(InterruptDecision(action=INTERRUPT_APPROVE))
    result = await agent.run(Session(id="hitl-approve"), "Write a note.")
    if result.output != "done" or len(tool.notes) != 1:
        raise RuntimeError(
            f"approve scenario failed: output={result.output!r} effects={len(tool.notes)}"
        )
    print("approve: written; effects=1", file=output)

    agent, tool = build_agent(InterruptDecision(
        action=INTERRUPT_EDIT,
        arguments={"text": "hello", "visibility": "private"},
    ))
    try:
        await agent.run(Session(id="hitl-edit"), "Write a note.")
    except PolicyDeniedError:
        if len(tool.notes) != 0:
            raise RuntimeError(f"edit produced effects={len(tool.notes)}")
    else:
        raise RuntimeError("edited private note was not denied")
    print("edit: policy rejected; effects=0", file=output)


if __name__ == "__main__":
    asyncio.run(run(sys.stdout))
