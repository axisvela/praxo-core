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

PORTFOLIO_ID = "portfolio-100"


class FixtureModel:
    def __init__(self, portfolio: str):
        self.portfolio = portfolio

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="compare-1", name="compare_claims",
                         arguments={"portfolio_id": self.portfolio}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="questions-1", name="draft_counsel_questions",
                         arguments={"portfolio_id": self.portfolio,
                                    "action": "draft_counsel_questions"}),
            ]))
        comparison = json.loads(tool_messages[0].content)
        questions = json.loads(tool_messages[-1].content)
        report = {
            "portfolio": comparison,
            "questions": questions,
            "legal_opinions": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class CompareClaimsTool:
    name = "compare_claims"
    description = "Compare fixed synthetic patent claims for FTO triage; no live patent search."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["portfolio_id"],
        "properties": {"portfolio_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("portfolio_id") != PORTFOLIO_ID:
            raise ValueError("portfolio outside fixture")
        if self.simulate_failure:
            raise RuntimeError("PATENT_INDEX_UNAVAILABLE")
        return {
            "portfolio_id": PORTFOLIO_ID,
            "families": 3,
            "overlapping_claims": 2,
            "expiring_soon": 1,
            "jurisdictions": ["US", "EP"],
            "source": "patent_fixture",
        }


class DraftCounselQuestionsTool:
    name = "draft_counsel_questions"
    description = "Draft review-only questions for counsel; never gives a legal opinion."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["portfolio_id", "action"],
        "properties": {
            "portfolio_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "questions_id": "counsel-100",
            "portfolio_id": args.get("portfolio_id"),
            "action": args.get("action"),
            "questions": [
                "Does the overlapping claim read on our product?",
                "Is the expiring family still enforceable in EP?",
                "Which jurisdictions need a formal opinion?",
            ],
            "status": "draft_only",
            "review_required": True,
            "legal_opinions": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "compare_claims":
        return Decision(
            allowed=action.arguments.get("portfolio_id") == PORTFOLIO_ID,
            reason="only portfolio-100 is in scope",
        )
    if action.tool_name == "draft_counsel_questions":
        return Decision(
            allowed=action.arguments.get("portfolio_id") == PORTFOLIO_ID
            and action.arguments.get("action") == "draft_counsel_questions",
            reason="only a review-only counsel-question draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_fto(portfolio: str = PORTFOLIO_ID, simulate_failure: bool = False):
    compare = CompareClaimsTool(simulate_failure=simulate_failure)
    draft = DraftCounselQuestionsTool()
    tools = Registry()
    tools.register(compare)
    tools.register(draft)
    agent = Agent(AgentOptions(
        model=FixtureModel(portfolio),
        tools=tools,
        max_steps=4,
        allowed_tools=["compare_claims", "draft_counsel_questions"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="patent-fto"),
                                 "Compare the fixed claims and draft counsel questions.")
        return result.output, compare.calls, draft.calls, None
    except Exception as error:
        return "", compare.calls, draft.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_fto())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["portfolio"]["overlapping_claims"] != 2:
        raise RuntimeError(f"unexpected claims: {report}")
    if report["questions"]["status"] != "draft_only" or report["legal_opinions"] != 0:
        raise RuntimeError(f"unexpected questions: {report}")

    _, reads, drafts, error = asyncio.run(run_fto("portfolio-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_fto(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python LJ-02 patent-fto tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--portfolio", default=PORTFOLIO_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_fto(args.portfolio, args.simulate_failure))
    if error:
        print(f"patent FTO failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
