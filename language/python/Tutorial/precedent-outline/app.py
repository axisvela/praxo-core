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

QUERY_ID = "query-100"


class FixtureModel:
    def __init__(self, query: str):
        self.query = query

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="search-1", name="search_precedents",
                         arguments={"query_id": self.query}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="outline-1", name="draft_outline",
                         arguments={"query_id": self.query, "action": "draft_outline"}),
            ]))
        precedents = json.loads(tool_messages[0].content)
        outline = json.loads(tool_messages[-1].content)
        report = {
            "precedents": precedents,
            "outline": outline,
            "sentencing_recommendations": 0,
            "judicial_decisions": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class SearchPrecedentsTool:
    name = "search_precedents"
    description = "Retrieve fixed synthetic precedents; no live legal database."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["query_id"],
        "properties": {"query_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("query_id") != QUERY_ID:
            raise ValueError("query outside fixture")
        if self.simulate_failure:
            raise RuntimeError("PRECEDENT_INDEX_UNAVAILABLE")
        return {
            "query_id": QUERY_ID,
            "precedents": 3,
            "matches": 2,
            "citations": ["case-1", "case-2"],
            "jurisprudence": "mixed",
            "source": "precedent_fixture",
        }


class DraftOutlineTool:
    name = "draft_outline"
    description = "Draft a cited review-only outline; never recommends a decision."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["query_id", "action"],
        "properties": {
            "query_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "outline_id": "outline-100",
            "query_id": args.get("query_id"),
            "action": args.get("action"),
            "sections": 2,
            "citations": ["case-1", "case-2"],
            "status": "draft_only",
            "review_required": True,
            "sentencing_recommendations": 0,
            "judicial_decisions": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "search_precedents":
        return Decision(
            allowed=action.arguments.get("query_id") == QUERY_ID,
            reason="only query-100 is in scope",
        )
    if action.tool_name == "draft_outline":
        return Decision(
            allowed=action.arguments.get("query_id") == QUERY_ID
            and action.arguments.get("action") == "draft_outline",
            reason="only a review-only outline draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_outline(query: str = QUERY_ID, simulate_failure: bool = False):
    search = SearchPrecedentsTool(simulate_failure=simulate_failure)
    draft = DraftOutlineTool()
    tools = Registry()
    tools.register(search)
    tools.register(draft)
    agent = Agent(AgentOptions(
        model=FixtureModel(query),
        tools=tools,
        max_steps=4,
        allowed_tools=["search_precedents", "draft_outline"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="precedent-outline"),
                                 "Retrieve fixed precedents and draft a cited outline.")
        return result.output, search.calls, draft.calls, None
    except Exception as error:
        return "", search.calls, draft.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_outline())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["precedents"]["matches"] != 2 or report["precedents"]["jurisprudence"] != "mixed":
        raise RuntimeError(f"unexpected precedents: {report}")
    if report["outline"]["status"] != "draft_only" or report["sentencing_recommendations"] != 0:
        raise RuntimeError(f"unexpected outline: {report}")

    _, reads, drafts, error = asyncio.run(run_outline("query-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_outline(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python LJ-04 precedent-outline tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", default=QUERY_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_outline(args.query, args.simulate_failure))
    if error:
        print(f"precedent outline failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
