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

REVIEW_ID = "review-100"
PAPERS = [
    {"id": "paper-100", "year": 2021, "finding": "intervention reduced symptoms"},
    {"id": "paper-101", "year": 2023, "finding": "effect varied by subgroup"},
]


class FixtureModel:
    def __init__(self, review: str):
        self.review = review

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="abstracts-1", name="retrieve_abstracts", arguments={
                    "review": self.review,
                }),
            ]))
        abstracts = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="hypotheses-1", name="draft_hypotheses", arguments={
                    "review": self.review,
                    "action": "draft",
                }),
            ]))
        hypotheses = json.loads(tool_messages[-1].content)
        report = {
            "stage": "hypotheses_drafted",
            "abstracts": abstracts,
            "hypotheses": hypotheses,
            "fabricated_papers": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class RetrieveAbstractsTool:
    name = "retrieve_abstracts"
    description = "Retrieve fixed synthetic abstracts; never invents papers."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["review"],
        "properties": {"review": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("review") != REVIEW_ID:
            raise ValueError("review outside fixture")
        if self.simulate_failure:
            raise RuntimeError("ABSTRACT_SOURCE_UNAVAILABLE")
        return {
            "review": REVIEW_ID,
            "papers": len(PAPERS),
            "citations": [paper["id"] for paper in PAPERS],
            "findings": [paper["finding"] for paper in PAPERS],
            "source": "abstract_fixture",
        }


class DraftHypothesesTool:
    name = "draft_hypotheses"
    description = "Draft unverified hypotheses citing fixed abstracts."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["review", "action"],
        "properties": {
            "review": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "hypothesis_id": "hypothesis-100",
            "review": args.get("review"),
            "action": args.get("action"),
            "citations": [paper["id"] for paper in PAPERS],
            "status": "draft_only",
            "unverified": True,
            "review_required": True,
            "fabricated_papers": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("review") != REVIEW_ID:
        return Decision(allowed=False, reason="only review-100 is in scope")
    if action.tool_name == "retrieve_abstracts":
        return Decision(allowed=True, reason="fixed abstract fixture")
    if action.tool_name == "draft_hypotheses":
        return Decision(
            allowed=action.arguments.get("action") == "draft",
            reason="only an unverified hypothesis draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_case(review: str = REVIEW_ID, simulate_failure: bool = False):
    abstracts = RetrieveAbstractsTool(simulate_failure=simulate_failure)
    hypotheses = DraftHypothesesTool()
    tools = Registry()
    tools.register(abstracts)
    tools.register(hypotheses)
    agent = Agent(AgentOptions(
        model=FixtureModel(review),
        tools=tools,
        max_steps=4,
        allowed_tools=["retrieve_abstracts", "draft_hypotheses"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="literature-review"),
                                 "Retrieve fixed abstracts and draft unverified hypotheses.")
        return result.output, abstracts.calls, hypotheses.calls, None
    except Exception as error:
        return "", abstracts.calls, hypotheses.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_case())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: {error}")
    report = json.loads(output)
    if (report["abstracts"]["papers"] != 2
            or report["abstracts"]["citations"] != ["paper-100", "paper-101"]
            or report["hypotheses"]["status"] != "draft_only"
            or report["hypotheses"]["unverified"] is not True
            or report["fabricated_papers"] != 0):
        raise RuntimeError(f"unexpected report: {report}")

    _, reads, drafts, error = asyncio.run(run_case("review-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError("scope denial failed")

    _, reads, drafts, error = asyncio.run(run_case(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError("dependency failure failed")

    print("Python SC-01 literature-review tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--review", default=REVIEW_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(
        run_case(args.review, args.simulate_failure))
    if error:
        print(f"literature review failed: reads={reads} drafts={drafts}; {error}",
              file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
