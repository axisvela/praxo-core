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

CAMPAIGN_ID = "campaign-100"
AUDIENCE = [
    {"id": "c1", "region": "north", "engagement": 0.9, "consent": True},
    {"id": "c2", "region": "north", "engagement": 0.7, "consent": True},
    {"id": "c3", "region": "south", "engagement": 0.4, "consent": True},
    {"id": "c4", "region": "south", "engagement": 0.8, "consent": False},
]


class FixtureModel:
    def __init__(self, campaign: str):
        self.campaign = campaign

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="segments-1", name="read_segments", arguments={
                    "campaign": self.campaign,
                }),
            ]))
        segments = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="content-1", name="draft_content", arguments={
                    "campaign": self.campaign,
                    "action": "draft",
                    "segment": segments["top_segment"],
                }),
            ]))
        content = json.loads(tool_messages[-1].content)
        report = {
            "stage": "content_drafted",
            "segments": segments,
            "content": content,
            "publications": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadSegmentsTool:
    name = "read_segments"
    description = "Compute fixed consent-aware audience segments; no publishing."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["campaign"],
        "properties": {"campaign": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("campaign") != CAMPAIGN_ID:
            raise ValueError("campaign outside fixture")
        if self.simulate_failure:
            raise RuntimeError("AUDIENCE_UNAVAILABLE")
        eligible = [item for item in AUDIENCE if item["consent"]]
        counts = {}
        for item in eligible:
            counts[item["region"]] = counts.get(item["region"], 0) + 1
        top = max(counts, key=lambda region: (counts[region], region))
        return {
            "campaign": CAMPAIGN_ID,
            "eligible": len(eligible),
            "excluded_no_consent": len(AUDIENCE) - len(eligible),
            "segments": counts,
            "top_segment": top,
            "source": "audience_fixture",
        }


class DraftContentTool:
    name = "draft_content"
    description = "Draft review-only content for one segment; never publishes."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["campaign", "action", "segment"],
        "properties": {
            "campaign": {"type": "string"},
            "action": {"type": "string"},
            "segment": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "content_id": "content-100",
            "campaign": args.get("campaign"),
            "segment": args.get("segment"),
            "action": args.get("action"),
            "status": "draft_only",
            "review_required": True,
            "publications": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("campaign") != CAMPAIGN_ID:
        return Decision(allowed=False, reason="only campaign-100 is in scope")
    if action.tool_name == "read_segments":
        return Decision(allowed=True, reason="fixed consent-aware fixture")
    if action.tool_name == "draft_content":
        return Decision(
            allowed=action.arguments.get("action") == "draft",
            reason="only a review-only content draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_case(campaign: str = CAMPAIGN_ID, simulate_failure: bool = False):
    segments = ReadSegmentsTool(simulate_failure=simulate_failure)
    content = DraftContentTool()
    tools = Registry()
    tools.register(segments)
    tools.register(content)
    agent = Agent(AgentOptions(
        model=FixtureModel(campaign),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_segments", "draft_content"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="marketing-segments"),
                                 "Compute fixed segments and draft review-only content.")
        return result.output, segments.calls, content.calls, None
    except Exception as error:
        return "", segments.calls, content.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_case())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: {error}")
    report = json.loads(output)
    if (report["segments"]["eligible"] != 3
            or report["segments"]["excluded_no_consent"] != 1
            or report["segments"]["top_segment"] != "north"
            or report["content"]["status"] != "draft_only"
            or report["publications"] != 0):
        raise RuntimeError(f"unexpected report: {report}")

    _, reads, drafts, error = asyncio.run(run_case("campaign-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError("scope denial failed")

    _, reads, drafts, error = asyncio.run(run_case(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError("dependency failure failed")

    print("Python CS-04 marketing-segments tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--campaign", default=CAMPAIGN_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(
        run_case(args.campaign, args.simulate_failure))
    if error:
        print(f"marketing segments failed: reads={reads} drafts={drafts}; {error}",
              file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
