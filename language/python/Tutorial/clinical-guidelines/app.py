from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.model import Message, Response, ToolCall
from praxo.policy import Decision, FuncHook
from praxo.tool import Registry

CONDITION_ID = "condition-100"

GUIDELINES = {
    "guideline-cardio": "For stable chest pain, start with a resting ECG and document risk factors.",
    "guideline-pharmacy": "Review interacting medications before changing an anticoagulant dose.",
}


class FixtureModel:
    def __init__(self, query: str, scope: str):
        self.query = query
        self.scope = scope

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="search-1", name="search_guidelines",
                         arguments={"query": self.query, "scope": self.scope}),
            ]))
        matches = json.loads(tool_messages[0].content)["matches"]
        if not matches:
            return Response(message=Message(role="assistant", content="INSUFFICIENT_EVIDENCE"))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="review-1", name="draft_review",
                         arguments={"condition": CONDITION_ID, "action": "review_only"}),
            ]))
        review = json.loads(tool_messages[-1].content)
        report = {
            "answer": matches[0]["snippet"],
            "citations": [match["id"] for match in matches[:1]],
            "review": review,
            "clinical_decisions": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class SearchGuidelinesTool:
    name = "search_guidelines"
    description = "Search fixed clinical guideline fixtures; no arbitrary records."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["query", "scope"],
        "properties": {
            "query": {"type": "string"},
            "scope": {"type": "string"},
        },
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("scope") != "public":
            raise ValueError("scope is not readable")
        if self.simulate_failure:
            raise RuntimeError("GUIDELINE_INDEX_UNAVAILABLE")
        tokens = re.findall(r"[a-z]+", str(args.get("query", "")).lower())
        matches = []
        for guideline_id, text in GUIDELINES.items():
            score = sum(1 for token in tokens if token in text.lower())
            if score:
                matches.append({"id": guideline_id, "score": score, "snippet": text})
        matches.sort(key=lambda item: (-item["score"], item["id"]))
        return {"scope": "public", "matches": matches[:2]}


class DraftReviewTool:
    name = "draft_review"
    description = "Draft a review-only guideline summary; never decides treatment."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["condition", "action"],
        "properties": {
            "condition": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "review_id": "clinical-100",
            "condition": args.get("condition"),
            "action": args.get("action"),
            "status": "draft_only",
            "review_required": True,
            "clinical_decisions": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "search_guidelines":
        return Decision(
            allowed=action.arguments.get("scope") == "public",
            reason="only public guideline fixtures are readable",
        )
    if action.tool_name == "draft_review":
        return Decision(
            allowed=action.arguments.get("condition") == CONDITION_ID
            and action.arguments.get("action") == "review_only",
            reason="only a condition-100 review_only draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_clinical(query: str = "chest pain ecg", scope: str = "public",
                       simulate_failure: bool = False, model=None):
    search = SearchGuidelinesTool(simulate_failure=simulate_failure)
    review = DraftReviewTool()
    tools = Registry()
    tools.register(search)
    tools.register(review)
    agent = Agent(AgentOptions(
        model=model or FixtureModel(query, scope),
        tools=tools,
        max_steps=4,
        allowed_tools=["search_guidelines", "draft_review"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="clinical-guidelines"), f"Review evidence for {query}.")
        return result.output, search.calls, review.calls, None
    except Exception as error:
        return "", search.calls, review.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_clinical())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["citations"] != ["guideline-cardio"]:
        raise RuntimeError(f"unexpected citations: {report}")
    if report["review"]["status"] != "draft_only" or report["clinical_decisions"] != 0:
        raise RuntimeError(f"unexpected review: {report}")

    abstain, reads, drafts, error = asyncio.run(run_clinical("unknown topic"))
    if error or abstain != "INSUFFICIENT_EVIDENCE" or reads != 1 or drafts != 0:
        raise RuntimeError(f"abstain failed: output={abstain} reads={reads} drafts={drafts}")

    _, reads, drafts, error = asyncio.run(run_clinical(scope="private"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_clinical(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python HC-01 clinical-guidelines tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", default="chest pain ecg")
    parser.add_argument("--scope", default="public")
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
    output, reads, drafts, error = asyncio.run(run_clinical(
        args.query, args.scope, args.simulate_failure, model=model))
    if error:
        print(f"clinical review failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
