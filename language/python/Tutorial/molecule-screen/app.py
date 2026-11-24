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

TARGET_ID = "target-100"


class FixtureModel:
    def __init__(self, target: str):
        self.target = target

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="rank-1", name="rank_candidates",
                         arguments={"target_id": self.target}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="review-1", name="draft_review",
                         arguments={"target_id": self.target, "action": "draft_review"}),
            ]))
        ranking = json.loads(tool_messages[0].content)
        review = json.loads(tool_messages[-1].content)
        report = {
            "ranking": ranking,
            "review": review,
            "efficacy_claims": 0,
            "toxicity_claims": 0,
            "syntheses": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class RankCandidatesTool:
    name = "rank_candidates"
    description = "Rank fixed synthetic molecular descriptors; no synthesis or efficacy claim."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["target_id"],
        "properties": {"target_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("target_id") != TARGET_ID:
            raise ValueError("target outside fixture")
        if self.simulate_failure:
            raise RuntimeError("MOLECULE_INDEX_UNAVAILABLE")
        return {
            "target_id": TARGET_ID,
            "candidates": 4,
            "top": "mol-2",
            "constraints_ok": True,
            "descriptors": {"mw": 342.1, "logp": 2.4, "hbd": 2},
            "source": "molecule_fixture",
        }


class DraftReviewTool:
    name = "draft_review"
    description = "Draft a review-only molecular assessment; never claims efficacy or toxicity."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["target_id", "action"],
        "properties": {
            "target_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "review_id": "molecule-review-100",
            "target_id": args.get("target_id"),
            "action": args.get("action"),
            "top": "mol-2",
            "status": "draft_only",
            "review_required": True,
            "efficacy_claims": 0,
            "toxicity_claims": 0,
            "syntheses": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "rank_candidates":
        return Decision(
            allowed=action.arguments.get("target_id") == TARGET_ID,
            reason="only target-100 is in scope",
        )
    if action.tool_name == "draft_review":
        return Decision(
            allowed=action.arguments.get("target_id") == TARGET_ID
            and action.arguments.get("action") == "draft_review",
            reason="only a review-only molecular draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_screen(target: str = TARGET_ID, simulate_failure: bool = False):
    ranking = RankCandidatesTool(simulate_failure=simulate_failure)
    review = DraftReviewTool()
    tools = Registry()
    tools.register(ranking)
    tools.register(review)
    agent = Agent(AgentOptions(
        model=FixtureModel(target),
        tools=tools,
        max_steps=4,
        allowed_tools=["rank_candidates", "draft_review"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="molecule-screen"),
                                 "Rank the fixed candidates and draft a review-only assessment.")
        return result.output, ranking.calls, review.calls, None
    except Exception as error:
        return "", ranking.calls, review.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_screen())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["ranking"]["top"] != "mol-2" or report["ranking"]["constraints_ok"] is not True:
        raise RuntimeError(f"unexpected ranking: {report}")
    if report["review"]["status"] != "draft_only" or report["efficacy_claims"] != 0 \
            or report["toxicity_claims"] != 0 or report["syntheses"] != 0:
        raise RuntimeError(f"unexpected review: {report}")

    _, reads, drafts, error = asyncio.run(run_screen("target-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_screen(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python SC-02 molecule-screen tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default=TARGET_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_screen(args.target, args.simulate_failure))
    if error:
        print(f"molecule screen failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
