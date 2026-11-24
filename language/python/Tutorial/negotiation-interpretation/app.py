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
                ToolCall(id="transcript-1", name="analyze_transcript", arguments={
                    "session": self.session,
                }),
            ]))
        analysis = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="notes-1", name="draft_notes", arguments={
                    "session": self.session,
                    "action": "draft",
                }),
            ]))
        notes = json.loads(tool_messages[-1].content)
        report = {
            "stage": "interpretation_notes_drafted",
            "analysis": analysis,
            "notes": notes,
            "mind_reading_claims": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class AnalyzeTranscriptTool:
    name = "analyze_transcript"
    description = "Compare fixed terms in one transcript; flag uncertainty."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["session"],
        "properties": {"session": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("session") != SESSION_ID:
            raise ValueError("session outside fixture")
        if self.simulate_failure:
            raise RuntimeError("TRANSCRIPT_UNAVAILABLE")
        return {
            "session": SESSION_ID,
            "turns": 4,
            "terms": [
                {"term": "deadline", "literal": "date", "context": "flexible"},
                {"term": "agreement", "literal": "consensus", "context": "conditional"},
            ],
            "uncertain_terms": 1,
            "mind_reading": False,
            "source": "transcript_fixture",
        }


class DraftNotesTool:
    name = "draft_notes"
    description = "Draft review-only interpretation notes; no mind reading."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["session", "action"],
        "properties": {
            "session": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "notes_id": "notes-100",
            "session": args.get("session"),
            "action": args.get("action"),
            "terms": 2,
            "uncertain_terms": 1,
            "status": "draft_only",
            "review_required": True,
            "mind_reading_claims": 0,
            "interpretation_guarantee": False,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("session") != SESSION_ID:
        return Decision(allowed=False, reason="only session-100 is in scope")
    if action.tool_name == "analyze_transcript":
        return Decision(allowed=True, reason="fixed transcript fixture")
    if action.tool_name == "draft_notes":
        return Decision(
            allowed=action.arguments.get("action") == "draft",
            reason="only review-only interpretation notes are allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_case(session: str = SESSION_ID, simulate_failure: bool = False):
    analysis = AnalyzeTranscriptTool(simulate_failure=simulate_failure)
    notes = DraftNotesTool()
    tools = Registry()
    tools.register(analysis)
    tools.register(notes)
    agent = Agent(AgentOptions(
        model=FixtureModel(session),
        tools=tools,
        max_steps=4,
        allowed_tools=["analyze_transcript", "draft_notes"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="negotiation-interpretation"),
                                 "Compare fixed terms and draft review-only notes.")
        return result.output, analysis.calls, notes.calls, None
    except Exception as error:
        return "", analysis.calls, notes.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_case())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: {error}")
    report = json.loads(output)
    if (report["analysis"]["turns"] != 4
            or len(report["analysis"]["terms"]) != 2
            or report["analysis"]["uncertain_terms"] != 1
            or report["notes"]["status"] != "draft_only"
            or report["mind_reading_claims"] != 0
            or report["notes"]["interpretation_guarantee"] is not False):
        raise RuntimeError(f"unexpected report: {report}")

    _, reads, drafts, error = asyncio.run(run_case("session-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError("scope denial failed")

    _, reads, drafts, error = asyncio.run(run_case(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError("dependency failure failed")

    print("Python OG-03 negotiation-interpretation tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", default=SESSION_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(
        run_case(args.session, args.simulate_failure))
    if error:
        print(f"negotiation interpretation failed: reads={reads} drafts={drafts}; {error}",
              file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
