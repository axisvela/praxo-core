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

TRIAL_ID = "trial-100"
PATIENTS = [
    {"id": "patient-1", "age": 45, "condition": "condition-100", "biomarker": True, "consent": True},
    {"id": "patient-2", "age": 30, "condition": "condition-100", "biomarker": False, "consent": True},
    {"id": "patient-3", "age": 60, "condition": "condition-100", "biomarker": True, "consent": False},
]


class FixtureModel:
    def __init__(self, trial: str):
        self.trial = trial

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="eligibility-1", name="evaluate_eligibility",
                         arguments={"trial": self.trial}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="screening-1", name="draft_screening",
                         arguments={"trial": self.trial, "action": "screen"}),
            ]))
        evidence = json.loads(tool_messages[0].content)
        screening = json.loads(tool_messages[-1].content)
        return Response(message=Message(role="assistant", content=json.dumps({
            "stage": "screening_drafted",
            "eligibility": evidence,
            "screening": screening,
            "enrollments": 0,
        })))


class EvaluateEligibilityTool:
    name = "evaluate_eligibility"
    description = "Evaluate fixed synthetic patients against trial criteria; no enrollment."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["trial"],
        "properties": {"trial": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("trial") != TRIAL_ID:
            raise ValueError("trial is not readable")
        if self.simulate_failure:
            raise RuntimeError("CRITERIA_SOURCE_UNAVAILABLE")
        eligible = []
        excluded = []
        for patient in PATIENTS:
            if patient["age"] < 18:
                excluded.append({"patient": patient["id"], "reason": "age"})
            elif patient["condition"] != "condition-100":
                excluded.append({"patient": patient["id"], "reason": "condition"})
            elif not patient["biomarker"]:
                excluded.append({"patient": patient["id"], "reason": "biomarker"})
            elif not patient["consent"]:
                excluded.append({"patient": patient["id"], "reason": "consent"})
            else:
                eligible.append(patient["id"])
        return {
            "trial": TRIAL_ID,
            "screened": len(PATIENTS),
            "eligible": eligible,
            "excluded": excluded,
            "unknowns": ["lab-availability"],
            "source": "trial_fixture",
        }


class DraftScreeningTool:
    name = "draft_screening"
    description = "Draft a review-only screening note; never enrolls a patient."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["trial", "action"],
        "properties": {
            "trial": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "screening_id": "screening-100",
            "trial": args.get("trial"),
            "action": args.get("action"),
            "status": "draft_only",
            "review_required": True,
            "enrollments": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "evaluate_eligibility":
        return Decision(
            allowed=action.arguments.get("trial") == TRIAL_ID,
            reason="only trial-100 is in screening scope",
        )
    if action.tool_name == "draft_screening":
        return Decision(
            allowed=action.arguments.get("trial") == TRIAL_ID
            and action.arguments.get("action") == "screen",
            reason="only a trial-100 screen draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_screening(trial: str = TRIAL_ID, simulate_failure: bool = False, model=None):
    evaluate = EvaluateEligibilityTool(simulate_failure=simulate_failure)
    screening = DraftScreeningTool()
    tools = Registry()
    tools.register(evaluate)
    tools.register(screening)
    agent = Agent(AgentOptions(
        model=model or FixtureModel(trial),
        tools=tools,
        max_steps=4,
        allowed_tools=["evaluate_eligibility", "draft_screening"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="trial-screening"), f"Screen patients for {trial}.")
        return result.output, evaluate.calls, screening.calls, None
    except Exception as error:
        return "", evaluate.calls, screening.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_screening())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    eligibility = report["eligibility"]
    if report["stage"] != "screening_drafted" or eligibility["eligible"] != ["patient-1"]:
        raise RuntimeError(f"unexpected report: {report}")
    if eligibility["screened"] != 3 or len(eligibility["excluded"]) != 2:
        raise RuntimeError(f"unexpected eligibility: {report}")
    if report["screening"]["status"] != "draft_only" or report["enrollments"] != 0:
        raise RuntimeError(f"unexpected screening: {report}")

    _, reads, drafts, error = asyncio.run(run_screening("trial-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_screening(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python HC-03 trial-screening tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trial", default=TRIAL_ID)
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
    output, reads, drafts, error = asyncio.run(run_screening(
        args.trial, args.simulate_failure, model=model))
    if error:
        print(f"trial screening failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
