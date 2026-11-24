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

MATTER_ID = "matter-100"
DOCUMENTS = [
    {"id": "doc-100", "date": "2023-01-10", "fact": "contract signed"},
    {"id": "doc-101", "date": "2023-02-01", "fact": "notice sent"},
    {"id": "doc-102", "date": "2023-01-20", "fact": "notice sent"},
]


class FixtureModel:
    def __init__(self, matter: str):
        self.matter = matter

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="timeline-1", name="build_timeline", arguments={
                    "matter": self.matter,
                }),
            ]))
        timeline = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="outline-1", name="draft_outline", arguments={
                    "matter": self.matter,
                    "action": "draft",
                }),
            ]))
        outline = json.loads(tool_messages[-1].content)
        report = {
            "stage": "examination_outline_drafted",
            "timeline": timeline,
            "outline": outline,
            "admissibility_claims": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class BuildTimelineTool:
    name = "build_timeline"
    description = "Build a cited timeline from fixed synthetic documents."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["matter"],
        "properties": {"matter": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("matter") != MATTER_ID:
            raise ValueError("matter outside fixture")
        if self.simulate_failure:
            raise RuntimeError("DOCUMENT_SET_UNAVAILABLE")
        ordered = sorted(DOCUMENTS, key=lambda item: (item["date"], item["id"]))
        notice_dates = sorted(doc["date"] for doc in DOCUMENTS if doc["fact"] == "notice sent")
        return {
            "matter": MATTER_ID,
            "documents": len(DOCUMENTS),
            "events": [
                {"date": doc["date"], "fact": doc["fact"], "citation": doc["id"]}
                for doc in ordered
            ],
            "contradictions": 1 if len(set(notice_dates)) > 1 else 0,
            "source": "document_fixture",
        }


class DraftOutlineTool:
    name = "draft_outline"
    description = "Draft a review-only examination outline; no legal advice."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["matter", "action"],
        "properties": {
            "matter": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "outline_id": "outline-100",
            "matter": args.get("matter"),
            "action": args.get("action"),
            "events": 3,
            "contradictions": 1,
            "status": "draft_only",
            "review_required": True,
            "legal_advice": False,
            "admissibility_claims": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("matter") != MATTER_ID:
        return Decision(allowed=False, reason="only matter-100 is in scope")
    if action.tool_name == "build_timeline":
        return Decision(allowed=True, reason="fixed document fixture")
    if action.tool_name == "draft_outline":
        return Decision(
            allowed=action.arguments.get("action") == "draft",
            reason="only a review-only outline is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_case(matter: str = MATTER_ID, simulate_failure: bool = False):
    timeline = BuildTimelineTool(simulate_failure=simulate_failure)
    outline = DraftOutlineTool()
    tools = Registry()
    tools.register(timeline)
    tools.register(outline)
    agent = Agent(AgentOptions(
        model=FixtureModel(matter),
        tools=tools,
        max_steps=4,
        allowed_tools=["build_timeline", "draft_outline"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="litigation-timeline"),
                                 "Build a cited timeline and draft an examination outline.")
        return result.output, timeline.calls, outline.calls, None
    except Exception as error:
        return "", timeline.calls, outline.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_case())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: {error}")
    report = json.loads(output)
    if (report["timeline"]["documents"] != 3
            or len(report["timeline"]["events"]) != 3
            or report["timeline"]["contradictions"] != 1
            or report["outline"]["status"] != "draft_only"
            or report["outline"]["legal_advice"] is not False
            or report["admissibility_claims"] != 0):
        raise RuntimeError(f"unexpected report: {report}")

    _, reads, drafts, error = asyncio.run(run_case("matter-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError("scope denial failed")

    _, reads, drafts, error = asyncio.run(run_case(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError("dependency failure failed")

    print("Python LJ-01 litigation-timeline tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--matter", default=MATTER_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(
        run_case(args.matter, args.simulate_failure))
    if error:
        print(f"litigation timeline failed: reads={reads} drafts={drafts}; {error}",
              file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
