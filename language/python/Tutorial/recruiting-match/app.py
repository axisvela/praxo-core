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

ROLE_ID = "role-100"
CANDIDATES = [
    {"id": "cand-1", "skills": {"go", "sql"}, "years": 5},
    {"id": "cand-2", "skills": {"python", "ml"}, "years": 3},
    {"id": "cand-3", "skills": {"go", "sql", "k8s"}, "years": 7},
]
REQUIRED = {"go", "sql"}
MIN_YEARS = 4


class FixtureModel:
    def __init__(self, role: str):
        self.role = role

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="role-1", name="read_role", arguments={"role": self.role}),
            ]))
        role = json.loads(tool_messages[0].content)
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="shortlist-1", name="draft_shortlist", arguments={
                    "role": self.role,
                    "action": "shortlist",
                    "candidate": role["ranked"][0],
                }),
            ]))
        shortlist = json.loads(tool_messages[-1].content)
        report = {
            "stage": "shortlist_drafted",
            "role": role,
            "shortlist": shortlist,
            "outreach_sent": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadRoleTool:
    name = "read_role"
    description = "Match fixed synthetic candidates against one role."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["role"],
        "properties": {"role": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("role") != ROLE_ID:
            raise ValueError("role outside fixture")
        if self.simulate_failure:
            raise RuntimeError("ROLE_SOURCE_UNAVAILABLE")
        matched = [
            candidate for candidate in CANDIDATES
            if REQUIRED <= candidate["skills"] and candidate["years"] >= MIN_YEARS
        ]
        ranked = sorted(matched, key=lambda item: (-item["years"], item["id"]))
        return {
            "role": ROLE_ID,
            "required": sorted(REQUIRED),
            "min_years": MIN_YEARS,
            "ranked": [candidate["id"] for candidate in ranked],
            "matched": len(ranked),
            "source": "candidate_fixture",
        }


class DraftShortlistTool:
    name = "draft_shortlist"
    description = "Draft a review-only shortlist; no candidate outreach."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["role", "action", "candidate"],
        "properties": {
            "role": {"type": "string"},
            "action": {"type": "string"},
            "candidate": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "shortlist_id": "shortlist-100",
            "role": args.get("role"),
            "candidate": args.get("candidate"),
            "action": args.get("action"),
            "status": "draft_only",
            "review_required": True,
            "outreach_sent": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("role") != ROLE_ID:
        return Decision(allowed=False, reason="only role-100 is in scope")
    if action.tool_name == "read_role":
        return Decision(allowed=True, reason="read-only candidate fixture")
    if action.tool_name == "draft_shortlist":
        return Decision(
            allowed=action.arguments.get("action") == "shortlist",
            reason="only a review-only shortlist is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_match(role: str = ROLE_ID, simulate_failure: bool = False):
    reader = ReadRoleTool(simulate_failure=simulate_failure)
    draft = DraftShortlistTool()
    tools = Registry()
    tools.register(reader)
    tools.register(draft)
    agent = Agent(AgentOptions(
        model=FixtureModel(role),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_role", "draft_shortlist"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="recruiting-match"),
                                 "Match the fixed candidates and draft a shortlist.")
        return result.output, reader.calls, draft.calls, None
    except Exception as error:
        return "", reader.calls, draft.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_match())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["role"]["ranked"] != ["cand-3", "cand-1"] or report["role"]["matched"] != 2:
        raise RuntimeError(f"unexpected ranking: {report}")
    if report["shortlist"]["status"] != "draft_only" or report["outreach_sent"] != 0:
        raise RuntimeError(f"unexpected shortlist: {report}")

    _, reads, drafts, error = asyncio.run(run_match("role-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_match(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python OP-05 recruiting-match tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--role", default=ROLE_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_match(args.role, args.simulate_failure))
    if error:
        print(f"recruiting match failed: reads={reads} drafts={drafts}; {error}",
              file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
