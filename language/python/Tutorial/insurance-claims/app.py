from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.middleware import StructuredOutput
from praxo.model import Message, Response, ToolCall
from praxo.policy import Decision, FuncHook
from praxo.tool import Registry

CLAIM_ID = "claim-100"

CLAIMS = {
    CLAIM_ID: {
        "claim_id": CLAIM_ID,
        "policy_id": "policy-77",
        "incident_type": "water_damage",
        "claimed_amount": 8500.0,
        "policy_limit": 10000.0,
        "evidence_items": 2,
        "days_to_report": 9,
        "prior_claims": 1,
    }
}

CLAIM_SCHEMA = {
    "type": "object",
    "required": [
        "claim_id",
        "risk_level",
        "recommended_payout",
        "requires_human_review",
        "mutating_actions",
    ],
    "properties": {
        "claim_id": {"type": "string"},
        "risk_level": {"type": "string", "enum": ["standard", "elevated"]},
        "recommended_payout": {"type": "number", "minimum": 0},
        "requires_human_review": {"type": "boolean"},
        "mutating_actions": {"type": "array"},
    },
}


def risk_level(claim: dict) -> str:
    ratio = claim["claimed_amount"] / claim["policy_limit"]
    if ratio > 0.6 or claim["evidence_items"] < 3:
        return "elevated"
    if claim["days_to_report"] > 7 or claim["prior_claims"] > 0:
        return "elevated"
    return "standard"


class FixtureModel:
    def __init__(self, claim_id: str):
        self.claim_id = claim_id

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="read-1", name="read_claim",
                         arguments={"claim_id": self.claim_id}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="draft-1", name="draft_decision",
                         arguments={"claim_id": self.claim_id}),
            ]))
        claim = json.loads(tool_messages[0].content)
        draft = json.loads(tool_messages[-1].content)
        report = {
            "claim_id": claim["claim_id"],
            "risk_level": claim["risk_level"],
            "recommended_payout": draft["recommended_payout"],
            "requires_human_review": draft["review_required"],
            "mutating_actions": [],
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadClaimTool:
    name = "read_claim"
    description = "Read a fixed claim file and compute deterministic risk signals."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["claim_id"],
        "properties": {"claim_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("claim_id") != CLAIM_ID:
            raise ValueError("claim is not readable")
        if self.simulate_failure:
            raise RuntimeError("simulated claim store unavailable")
        claim = dict(CLAIMS[CLAIM_ID])
        claim["usage_ratio"] = round(claim["claimed_amount"] / claim["policy_limit"], 2)
        claim["risk_level"] = risk_level(claim)
        claim["source"] = "claim_fixture"
        return claim


class DraftDecisionTool:
    name = "draft_decision"
    description = "Draft a review-only decision without executing a payment."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["claim_id"],
        "properties": {"claim_id": {"type": "string"}},
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        claim = CLAIMS[args.get("claim_id")]
        payout = min(claim["claimed_amount"], claim["policy_limit"])
        return {
            "claim_id": claim["claim_id"],
            "status": "draft_only",
            "review_required": True,
            "recommended_payout": payout,
            "payment_executed": False,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind == "tool.invoke":
        allowed = (
            action.tool_name in {"read_claim", "draft_decision"}
            and action.arguments.get("claim_id") == CLAIM_ID
        )
        return Decision(
            allowed=allowed,
            reason="only claim-100 review is permitted",
        )
    return Decision(allowed=False, reason="unsupported action")


async def run_claim(claim_id: str = CLAIM_ID, simulate_failure: bool = False, model=None):
    read_tool = ReadClaimTool(simulate_failure=simulate_failure)
    draft_tool = DraftDecisionTool()
    tools = Registry()
    tools.register(read_tool)
    tools.register(draft_tool)
    agent = Agent(AgentOptions(
        model=model or FixtureModel(claim_id),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_claim", "draft_decision"],
        policy=FuncHook(authorize),
        structured_output=StructuredOutput(schema=CLAIM_SCHEMA),
    ))
    try:
        result = await agent.run(Session(id="insurance-claims"), f"Review claim {claim_id}.")
        return result.output, read_tool.calls, draft_tool.calls, None
    except Exception as error:
        return "", read_tool.calls, draft_tool.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_claim())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["claim_id"] != CLAIM_ID or report["risk_level"] != "elevated":
        raise RuntimeError(f"unexpected risk: {report}")
    if report["recommended_payout"] != 8500 or not report["requires_human_review"]:
        raise RuntimeError(f"unexpected decision: {report}")
    if report["mutating_actions"]:
        raise RuntimeError("unexpected mutating action")

    _, reads, drafts, error = asyncio.run(run_claim("claim-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_claim(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts} error={error}")

    print("Python insurance-claims tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--claim", default=CLAIM_ID)
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
    output, reads, drafts, error = asyncio.run(run_claim(
        args.claim, args.simulate_failure, model=model))
    if error:
        print(f"claims triage failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
