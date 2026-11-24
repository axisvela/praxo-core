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

HUNT_ID = "hunt-100"
EVENTS = [
    {"id": "event-100", "hour": 9, "action": "signin", "ttp": None},
    {"id": "event-101", "hour": 9, "action": "process_start", "ttp": "T1059"},
    {"id": "event-102", "hour": 10, "action": "outbound_connect", "ttp": "T1071"},
]


class FixtureModel:
    def __init__(self, hunt: str):
        self.hunt = hunt

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="logs-1", name="search_logs", arguments={"hunt": self.hunt}),
            ]))
        search = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="timeline-1", name="draft_timeline", arguments={
                    "hunt": self.hunt,
                    "action": "draft",
                }),
            ]))
        timeline = json.loads(tool_messages[-1].content)
        report = {
            "stage": "ttp_timeline_drafted",
            "search": search,
            "timeline": timeline,
            "external_intel": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class SearchLogsTool:
    name = "search_logs"
    description = "Search fixed synthetic logs and cite matching events."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["hunt"],
        "properties": {"hunt": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("hunt") != HUNT_ID:
            raise ValueError("hunt outside fixture")
        if self.simulate_failure:
            raise RuntimeError("LOG_SOURCE_UNAVAILABLE")
        ttp_events = [event for event in EVENTS if event["ttp"]]
        return {
            "hunt": HUNT_ID,
            "events": len(EVENTS),
            "matched": len(ttp_events),
            "citations": [event["id"] for event in ttp_events],
            "ttps": [event["ttp"] for event in ttp_events],
            "source": "log_fixture",
        }


class DraftTimelineTool:
    name = "draft_timeline"
    description = "Draft a cited synthetic TTP timeline; no live intelligence."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["hunt", "action"],
        "properties": {
            "hunt": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "timeline_id": "timeline-100",
            "hunt": args.get("hunt"),
            "action": args.get("action"),
            "entries": [
                {"hour": 9, "ttp": "T1059", "citation": "event-101"},
                {"hour": 10, "ttp": "T1071", "citation": "event-102"},
            ],
            "status": "draft_only",
            "review_required": True,
            "apt_guarantee": False,
            "external_intel": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("hunt") != HUNT_ID:
        return Decision(allowed=False, reason="only hunt-100 is in scope")
    if action.tool_name == "search_logs":
        return Decision(allowed=True, reason="fixed log fixture")
    if action.tool_name == "draft_timeline":
        return Decision(
            allowed=action.arguments.get("action") == "draft",
            reason="only a cited review-only timeline is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_case(hunt: str = HUNT_ID, simulate_failure: bool = False):
    search = SearchLogsTool(simulate_failure=simulate_failure)
    timeline = DraftTimelineTool()
    tools = Registry()
    tools.register(search)
    tools.register(timeline)
    agent = Agent(AgentOptions(
        model=FixtureModel(hunt),
        tools=tools,
        max_steps=4,
        allowed_tools=["search_logs", "draft_timeline"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="threat-hunting"),
                                 "Search fixed logs and draft a cited TTP timeline.")
        return result.output, search.calls, timeline.calls, None
    except Exception as error:
        return "", search.calls, timeline.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_case())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: {error}")
    report = json.loads(output)
    if (report["search"]["events"] != 3
            or report["search"]["matched"] != 2
            or report["search"]["ttps"] != ["T1059", "T1071"]
            or report["timeline"]["status"] != "draft_only"
            or len(report["timeline"]["entries"]) != 2
            or report["external_intel"] != 0):
        raise RuntimeError(f"unexpected report: {report}")

    _, reads, drafts, error = asyncio.run(run_case("hunt-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError("scope denial failed")

    _, reads, drafts, error = asyncio.run(run_case(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError("dependency failure failed")

    print("Python CY-03 threat-hunting tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hunt", default=HUNT_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(
        run_case(args.hunt, args.simulate_failure))
    if error:
        print(f"threat hunting failed: reads={reads} drafts={drafts}; {error}",
              file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
