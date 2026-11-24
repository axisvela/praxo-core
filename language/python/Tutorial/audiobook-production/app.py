from __future__ import annotations

import argparse
import asyncio
import json
import sys

from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.model import Message, Response, ToolCall
from praxo.policy import Decision, FuncHook
from praxo.tool import Registry

BOOK_ID = "book-100"


class FixtureModel:
    def __init__(self, book: str):
        self.book = book

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="plan-1", name="plan_audio", arguments={"book": self.book}),
            ]))
        plan = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="mix-1", name="draft_mix", arguments={
                    "book": self.book,
                    "action": "plan",
                }),
            ]))
        mix = json.loads(tool_messages[-1].content)
        report = {
            "stage": "mix_plan_drafted",
            "plan": plan,
            "mix": mix,
            "renders": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class PlanAudioTool:
    name = "plan_audio"
    description = "Plan fixed licensed voices and mixing cues; no synthesis."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["book"],
        "properties": {"book": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("book") != BOOK_ID:
            raise ValueError("book outside fixture")
        if self.simulate_failure:
            raise RuntimeError("AUDIO_PLAN_UNAVAILABLE")
        return {
            "book": BOOK_ID,
            "chapters": 3,
            "characters": [
                {"id": "character-100", "voice": "licensed-voice-a"},
                {"id": "character-101", "voice": "licensed-voice-b"},
            ],
            "mixing_cues": 4,
            "rights_verified": False,
            "source": "book_fixture",
        }


class DraftMixTool:
    name = "draft_mix"
    description = "Draft a review-only mixing plan; no synthesis or rendering."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["book", "action"],
        "properties": {
            "book": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "mix_id": "mix-100",
            "book": args.get("book"),
            "action": args.get("action"),
            "chapters": 3,
            "voices": 2,
            "cues": 4,
            "status": "draft_only",
            "review_required": True,
            "renders": 0,
            "rights_guarantee": False,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("book") != BOOK_ID:
        return Decision(allowed=False, reason="only book-100 is in scope")
    if action.tool_name == "plan_audio":
        return Decision(allowed=True, reason="fixed licensed book fixture")
    if action.tool_name == "draft_mix":
        return Decision(
            allowed=action.arguments.get("action") == "plan",
            reason="only a review-only mix plan is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_case(book: str = BOOK_ID, simulate_failure: bool = False):
    plan = PlanAudioTool(simulate_failure=simulate_failure)
    mix = DraftMixTool()
    tools = Registry()
    tools.register(plan)
    tools.register(mix)
    agent = Agent(AgentOptions(
        model=FixtureModel(book),
        tools=tools,
        max_steps=4,
        allowed_tools=["plan_audio", "draft_mix"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="audiobook-production"),
                                 "Plan fixed voices and draft a review-only mix.")
        return result.output, plan.calls, mix.calls, None
    except Exception as error:
        return "", plan.calls, mix.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_case())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: {error}")
    report = json.loads(output)
    if (report["plan"]["chapters"] != 3
            or len(report["plan"]["characters"]) != 2
            or report["plan"]["mixing_cues"] != 4
            or report["mix"]["status"] != "draft_only"
            or report["renders"] != 0
            or report["mix"]["rights_guarantee"] is not False):
        raise RuntimeError(f"unexpected report: {report}")

    _, reads, drafts, error = asyncio.run(run_case("book-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError("scope denial failed")

    _, reads, drafts, error = asyncio.run(run_case(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError("dependency failure failed")

    print("Python MD-06 audiobook-production tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--book", default=BOOK_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(
        run_case(args.book, args.simulate_failure))
    if error:
        print(f"audiobook production failed: reads={reads} drafts={drafts}; {error}",
              file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
