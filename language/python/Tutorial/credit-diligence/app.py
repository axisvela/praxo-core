from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.model import Message, Response, ToolCall
from praxo.policy import Decision, FuncHook
from praxo.tool import Registry

APPLICANT_ID = "applicant-100"


class FixtureModel:
    def __init__(self, applicant: str):
        self.applicant = applicant

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="financials-1", name="read_financials",
                         arguments={"applicant": self.applicant}),
            ]))
        financials = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="memo-1", name="draft_memo",
                         arguments={"applicant": self.applicant, "action": "review_only"}),
            ]))
        memo = json.loads(tool_messages[-1].content)
        return Response(message=Message(role="assistant", content=json.dumps({
            "stage": "credit_memo_drafted",
            "financials": financials,
            "memo": memo,
            "credit_decisions": 0,
        })))


class ReadFinancialsTool:
    name = "read_financials"
    description = "Compute fixed credit ratios from a synthetic applicant; no bureau call."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["applicant"],
        "properties": {"applicant": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("applicant") != APPLICANT_ID:
            raise ValueError("applicant is not readable")
        if self.simulate_failure:
            raise RuntimeError("BUREAU_UNAVAILABLE")
        revenue = 1_200_000.0
        debt = 900_000.0
        related = 250_000.0
        delinquencies = 2
        debt_ratio = round(debt / revenue, 2)
        related_ratio = round(related / revenue, 2)
        risk = "elevated" if debt_ratio > 0.7 or related_ratio > 0.15 or delinquencies >= 2 else "standard"
        return {
            "applicant": APPLICANT_ID,
            "revenue": revenue,
            "debt": debt,
            "debt_ratio": debt_ratio,
            "related_party_txn": related,
            "related_party_ratio": related_ratio,
            "delinquencies": delinquencies,
            "risk": risk,
            "source": "financial_fixture",
        }


class DraftMemoTool:
    name = "draft_memo"
    description = "Draft a review-only credit memo; never approves or declines."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["applicant", "action"],
        "properties": {
            "applicant": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "memo_id": "credit-100",
            "applicant": args.get("applicant"),
            "action": args.get("action"),
            "status": "draft_only",
            "review_required": True,
            "credit_decisions": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("applicant") != APPLICANT_ID:
        return Decision(allowed=False, reason="only applicant-100 is in diligence scope")
    if action.tool_name == "read_financials":
        return Decision(allowed=True)
    if action.tool_name == "draft_memo":
        return Decision(
            allowed=action.arguments.get("action") == "review_only",
            reason="only a review_only memo draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_diligence(applicant: str = APPLICANT_ID, simulate_failure: bool = False, model=None):
    read_tool = ReadFinancialsTool(simulate_failure=simulate_failure)
    memo_tool = DraftMemoTool()
    tools = Registry()
    tools.register(read_tool)
    tools.register(memo_tool)
    agent = Agent(AgentOptions(
        model=model or FixtureModel(applicant),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_financials", "draft_memo"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="credit-diligence"), f"Review applicant {applicant}.")
        return result.output, read_tool.calls, memo_tool.calls, None
    except Exception as error:
        return "", read_tool.calls, memo_tool.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_diligence())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    financials = report["financials"]
    if report["stage"] != "credit_memo_drafted" or financials["risk"] != "elevated":
        raise RuntimeError(f"unexpected report: {report}")
    if financials["debt_ratio"] != 0.75 or report["credit_decisions"] != 0:
        raise RuntimeError(f"unexpected metrics: {report}")
    if report["memo"]["status"] != "draft_only":
        raise RuntimeError(f"unexpected memo: {report}")

    _, reads, drafts, error = asyncio.run(run_diligence("applicant-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_diligence(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python FC-03 credit-diligence tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--applicant", default=APPLICANT_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    parser.add_argument("--live", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    model = None
    if args.live:
        model = OpenAICompatibleModel(OpenAIConfig(
            base_url=os.getenv("PRAXO_BASE_URL", "http://127.0.0.1:11434/v1"),
            api_key=os.getenv("PRAXO_API_KEY", ""),
            model=os.getenv("PRAXO_MODEL", "qwen2.5:0.5b"),
        ))
    output, reads, drafts, error = asyncio.run(run_diligence(
        args.applicant, args.simulate_failure, model=model))
    if error:
        print(f"credit diligence failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
