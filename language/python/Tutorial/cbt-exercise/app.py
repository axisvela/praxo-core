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

SESSION_ID = "session-100"


class FixtureModel:
    def __init__(self, session: str):
        self.session = session

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="exercise-1", name="read_exercise",
                         arguments={"session_id": self.session}),
            ]))
        exercise = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="summary-1", name="draft_summary",
                         arguments={"session_id": self.session, "action": "draft_summary"}),
            ]))
        summary = json.loads(tool_messages[-1].content)
        report = {
            "exercise": exercise,
            "summary": summary,
            "therapist_replacement": 0,
            "unsupervised_crisis": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadExerciseTool:
    name = "read_exercise"
    description = "Read a fixed CBT exercise and crisis flag; no live session."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["session_id"],
        "properties": {"session_id": {"type": "string"}},
    }

    def __init__(self, crisis: bool = False, simulate_failure: bool = False):
        self.calls = 0
        self.crisis = crisis
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("session_id") != SESSION_ID:
            raise ValueError("session outside fixture")
        if self.simulate_failure:
            raise RuntimeError("EXERCISE_INDEX_UNAVAILABLE")
        return {
            "session_id": SESSION_ID,
            "exercise": "breathing",
            "steps": 3,
            "crisis_flag": self.crisis,
            "escalation": "human_review",
            "source": "exercise_fixture",
        }


class DraftSummaryTool:
    name = "draft_summary"
    description = "Draft a review-only exercise summary; never replaces a therapist."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["session_id", "action"],
        "properties": {
            "session_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "summary_id": "cbt-100",
            "session_id": args.get("session_id"),
            "action": args.get("action"),
            "escalated": False,
            "status": "draft_only",
            "review_required": True,
            "therapist_replacement": 0,
            "unsupervised_crisis": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "read_exercise":
        return Decision(
            allowed=action.arguments.get("session_id") == SESSION_ID,
            reason="only session-100 is in scope",
        )
    if action.tool_name == "draft_summary":
        return Decision(
            allowed=action.arguments.get("session_id") == SESSION_ID
            and action.arguments.get("action") == "draft_summary",
            reason="only a review-only summary draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_exercise(session: str = SESSION_ID, crisis: bool = False,
                       simulate_failure: bool = False):
    exercise = ReadExerciseTool(crisis=crisis, simulate_failure=simulate_failure)
    summary = DraftSummaryTool()
    tools = Registry()
    tools.register(exercise)
    tools.register(summary)
    agent = Agent(AgentOptions(
        model=FixtureModel(session),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_exercise", "draft_summary"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="cbt-exercise"),
                                 "Read the fixed exercise and draft a review-only summary.")
        return result.output, exercise.calls, summary.calls, None
    except Exception as error:
        return "", exercise.calls, summary.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_exercise())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["exercise"]["crisis_flag"] is not False or report["exercise"]["steps"] != 3:
        raise RuntimeError(f"unexpected exercise: {report}")
    if report["summary"]["status"] != "draft_only" or report["therapist_replacement"] != 0:
        raise RuntimeError(f"unexpected summary: {report}")

    crisis_output, reads, drafts, error = asyncio.run(run_exercise(crisis=True))
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"crisis path failed: reads={reads} drafts={drafts} error={error}")
    crisis = json.loads(crisis_output)
    if crisis["exercise"]["crisis_flag"] is not True \
            or crisis["exercise"]["escalation"] != "human_review":
        raise RuntimeError(f"crisis escalation missing: {crisis}")

    _, reads, drafts, error = asyncio.run(run_exercise("session-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_exercise(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python HC-05 cbt-exercise tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", default=SESSION_ID)
    parser.add_argument("--crisis", action="store_true")
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_exercise(
        args.session, args.crisis, args.simulate_failure))
    if error:
        print(f"CBT exercise failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
