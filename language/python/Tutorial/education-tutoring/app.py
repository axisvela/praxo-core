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
from praxo.retriever import Document
from praxo.tool import Registry

LESSONS = [
    Document(
        id="lesson-fractions",
        content="Equivalent fractions multiply the numerator and denominator by the same number.",
        metadata={"topic": "fractions", "grade": "4"},
    ),
    Document(
        id="lesson-decimals",
        content="Place value covers tenths, hundredths, and thousandths.",
        metadata={"topic": "decimals", "grade": "4"},
    ),
    Document(
        id="lesson-ratios",
        content="A ratio table compares two quantities at the same rate.",
        metadata={"topic": "ratios", "grade": "6"},
    ),
]


class LessonRetriever:
    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def retrieve(self, query: str, limit: int) -> list[Document]:
        self.calls += 1
        if self.simulate_failure:
            raise RuntimeError("simulated lesson index unavailable")
        tokens = re.findall(r"[a-z]+", query.lower())
        matches: list[Document] = []
        for lesson in LESSONS:
            text = (lesson.content + " " + lesson.metadata.get("topic", "")).lower()
            score = sum(1 for token in tokens if token in text)
            if score:
                matches.append(Document(
                    id=lesson.id,
                    content=lesson.content,
                    metadata=dict(lesson.metadata),
                    score=float(score),
                ))
        matches.sort(key=lambda item: (-item.score, item.id))
        return matches[:limit]


class FixtureModel:
    def __init__(self, query: str, scope: str):
        self.query = query
        self.scope = scope

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="search-1", name="search_lessons",
                         arguments={"query": self.query, "scope": self.scope}),
            ]))
        matches = json.loads(tool_messages[0].content)["matches"]
        if len(tool_messages) == 1:
            topic = matches[0]["id"] if matches else ""
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="plan-1", name="draft_study_plan",
                         arguments={"topic": topic, "action": "assign_review"}),
            ]))
        plan = json.loads(tool_messages[-1].content)
        report = {
            "answer": matches[0]["snippet"] if matches else "No lesson matched.",
            "citations": [match["id"] for match in matches[:1]],
            "plan": plan,
            "assignments_created": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class SearchLessonsTool:
    name = "search_lessons"
    description = "Search the application-owned lesson retriever; no arbitrary files."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["query", "scope"],
        "properties": {
            "query": {"type": "string"},
            "scope": {"type": "string"},
        },
    }

    def __init__(self, retriever: LessonRetriever):
        self.retriever = retriever

    async def invoke(self, args):
        documents = await self.retriever.retrieve(str(args.get("query", "")), 2)
        return {
            "scope": args.get("scope"),
            "matches": [
                {"id": doc.id, "snippet": doc.content, "score": doc.score}
                for doc in documents
            ],
        }


class DraftStudyPlanTool:
    name = "draft_study_plan"
    description = "Draft a review-only study plan; never creates assignments."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["topic", "action"],
        "properties": {
            "topic": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "plan_id": "plan-100",
            "topic": args.get("topic"),
            "action": args.get("action"),
            "status": "draft_only",
            "review_required": True,
            "assignments_created": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind == "tool.invoke":
        if action.tool_name == "search_lessons":
            return Decision(
                allowed=action.arguments.get("scope") == "public",
                reason="only the public lesson corpus is readable",
            )
        if action.tool_name == "draft_study_plan":
            return Decision(
                allowed=action.arguments.get("action") == "assign_review",
                reason="only a draft study plan is allowed",
            )
    return Decision(allowed=False, reason="unsupported action")


async def run_tutoring(
    query: str = "fractions",
    scope: str = "public",
    simulate_failure: bool = False,
    model=None,
):
    retriever = LessonRetriever(simulate_failure=simulate_failure)
    draft = DraftStudyPlanTool()
    tools = Registry()
    tools.register(SearchLessonsTool(retriever))
    tools.register(draft)
    agent = Agent(AgentOptions(
        model=model or FixtureModel(query, scope),
        tools=tools,
        max_steps=4,
        allowed_tools=["search_lessons", "draft_study_plan"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="education-tutoring"), f"Plan a lesson for {query}.")
        return result.output, retriever.calls, draft.calls, None
    except Exception as error:
        return "", retriever.calls, draft.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_tutoring())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["citations"] != ["lesson-fractions"]:
        raise RuntimeError(f"unexpected citations: {report}")
    if "numerator" not in report["answer"]:
        raise RuntimeError(f"unexpected answer: {report}")
    if report["plan"]["status"] != "draft_only" or report["assignments_created"] != 0:
        raise RuntimeError(f"unexpected plan: {report}")

    _, reads, drafts, error = asyncio.run(run_tutoring(scope="private"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_tutoring(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts} error={error}")

    print("Python education-tutoring tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", default="fractions")
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
    output, reads, drafts, error = asyncio.run(run_tutoring(
        args.query, args.scope, args.simulate_failure, model=model))
    if error:
        print(f"tutoring failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
