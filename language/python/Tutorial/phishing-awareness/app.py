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

EMAIL_ID = "email-100"

INDICATORS = [
    {"id": "spoofed-sender", "severity": "high"},
    {"id": "suspicious-link", "severity": "high"},
    {"id": "urgency-pressure", "severity": "medium"},
]


class FixtureModel:
    def __init__(self, email: str):
        self.email = email

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="analyze-1", name="analyze_email",
                         arguments={"email_id": self.email}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="exercise-1", name="draft_awareness",
                         arguments={"email_id": self.email, "action": "draft_exercise"}),
            ]))
        analysis = json.loads(tool_messages[0].content)
        exercise = json.loads(tool_messages[-1].content)
        report = {
            "analysis": analysis,
            "exercise": exercise,
            "deceptive_sends": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class AnalyzeEmailTool:
    name = "analyze_email"
    description = "Analyze a fixed synthetic email for awareness training; sends nothing."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["email_id"],
        "properties": {"email_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("email_id") != EMAIL_ID:
            raise ValueError("email outside fixture")
        if self.simulate_failure:
            raise RuntimeError("EMAIL_INDEX_UNAVAILABLE")
        return {
            "email_id": EMAIL_ID,
            "subject": "Urgent: verify your account now",
            "indicators": INDICATORS,
            "indicator_count": len(INDICATORS),
            "source": "email_fixture",
        }


class DraftAwarenessTool:
    name = "draft_awareness"
    description = "Draft a review-only awareness exercise; never sends deceptive mail."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["email_id", "action"],
        "properties": {
            "email_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "exercise_id": "awareness-100",
            "email_id": args.get("email_id"),
            "action": args.get("action"),
            "status": "draft_only",
            "review_required": True,
            "deceptive_sends": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "analyze_email":
        return Decision(
            allowed=action.arguments.get("email_id") == EMAIL_ID,
            reason="only email-100 is in scope",
        )
    if action.tool_name == "draft_awareness":
        return Decision(
            allowed=action.arguments.get("email_id") == EMAIL_ID
            and action.arguments.get("action") == "draft_exercise",
            reason="only a review-only awareness draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_phishing(email: str = EMAIL_ID, simulate_failure: bool = False):
    analyze = AnalyzeEmailTool(simulate_failure=simulate_failure)
    draft = DraftAwarenessTool()
    tools = Registry()
    tools.register(analyze)
    tools.register(draft)
    agent = Agent(AgentOptions(
        model=FixtureModel(email),
        tools=tools,
        max_steps=4,
        allowed_tools=["analyze_email", "draft_awareness"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="phishing-awareness"),
                                 "Analyze the fixed email and draft an awareness exercise.")
        return result.output, analyze.calls, draft.calls, None
    except Exception as error:
        return "", analyze.calls, draft.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_phishing())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["analysis"]["indicator_count"] != 3:
        raise RuntimeError(f"unexpected analysis: {report}")
    if report["exercise"]["status"] != "draft_only" or report["deceptive_sends"] != 0:
        raise RuntimeError(f"unexpected exercise: {report}")

    _, reads, drafts, error = asyncio.run(run_phishing("email-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_phishing(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python CY-04 phishing-awareness tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", default=EMAIL_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_phishing(args.email, args.simulate_failure))
    if error:
        print(f"phishing analysis failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
