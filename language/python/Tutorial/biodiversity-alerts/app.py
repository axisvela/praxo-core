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

REGION_ID = "region-100"


class FixtureModel:
    def __init__(self, region: str):
        self.region = region

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="observations-1", name="read_observations",
                         arguments={"region_id": self.region}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="review-1", name="draft_ranger_review",
                         arguments={"region_id": self.region, "action": "draft_review"}),
            ]))
        observations = json.loads(tool_messages[0].content)
        review = json.loads(tool_messages[-1].content)
        report = {
            "observations": observations,
            "review": review,
            "pursuits": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadObservationsTool:
    name = "read_observations"
    description = "Classify fixed labeled observations; no species-recognition guarantee."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["region_id"],
        "properties": {"region_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("region_id") != REGION_ID:
            raise ValueError("region outside fixture")
        if self.simulate_failure:
            raise RuntimeError("OBSERVATION_INDEX_UNAVAILABLE")
        return {
            "region_id": REGION_ID,
            "observations": 3,
            "labeled": 3,
            "flagged": 1,
            "confidence": "low",
            "source": "observation_fixture",
        }


class DraftRangerReviewTool:
    name = "draft_ranger_review"
    description = "Draft a review-only ranger alert; never dispatches pursuit."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["region_id", "action"],
        "properties": {
            "region_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "review_id": "ranger-100",
            "region_id": args.get("region_id"),
            "action": args.get("action"),
            "items": ["Recheck camera-trap 3", "Confirm the low-confidence label"],
            "status": "draft_only",
            "review_required": True,
            "species_claims": 0,
            "pursuits": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "read_observations":
        return Decision(
            allowed=action.arguments.get("region_id") == REGION_ID,
            reason="only region-100 is in scope",
        )
    if action.tool_name == "draft_ranger_review":
        return Decision(
            allowed=action.arguments.get("region_id") == REGION_ID
            and action.arguments.get("action") == "draft_review",
            reason="only a review-only ranger alert is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_alerts(region: str = REGION_ID, simulate_failure: bool = False):
    observations = ReadObservationsTool(simulate_failure=simulate_failure)
    review = DraftRangerReviewTool()
    tools = Registry()
    tools.register(observations)
    tools.register(review)
    agent = Agent(AgentOptions(
        model=FixtureModel(region),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_observations", "draft_ranger_review"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="biodiversity-alerts"),
                                 "Classify fixed observations and draft a ranger review.")
        return result.output, observations.calls, review.calls, None
    except Exception as error:
        return "", observations.calls, review.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_alerts())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["observations"]["flagged"] != 1:
        raise RuntimeError(f"unexpected observations: {report}")
    if report["review"]["status"] != "draft_only" or report["pursuits"] != 0:
        raise RuntimeError(f"unexpected review: {report}")

    _, reads, drafts, error = asyncio.run(run_alerts("region-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_alerts(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python AE-05 biodiversity-alerts tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--region", default=REGION_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_alerts(args.region, args.simulate_failure))
    if error:
        print(f"biodiversity alerts failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
