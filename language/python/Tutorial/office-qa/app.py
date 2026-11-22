from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys
from urllib.parse import urlsplit

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.model import Message, Response, ToolCall
from praxo.policy import Decision, FuncHook
from praxo.tool import Registry

DOCUMENTS = {
    "handbook": (
        "Expense reports are due on the fifth. Travel requires manager approval. "
        "Attach receipts to every expense report."
    ),
    "security": (
        "Use the password manager for all shared credentials. Report a lost device "
        "within 24 hours. Never share credentials in email."
    ),
    "benefits": (
        "Health enrollment opens in November. Update dependants within 30 days of "
        "a qualifying life event."
    ),
}


class FixtureModel:
    def __init__(self, query: str, scope: str):
        self.query = query
        self.scope = scope

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if tool_messages:
            evidence = json.loads(tool_messages[-1].content)
            top = evidence["matches"][0] if evidence["matches"] else None
            if top is None:
                report = {"answer": "No matching policy document was found.", "citations": [], "matches": []}
            else:
                report = {
                    "answer": f"According to {top['id']}: {top['snippet']}",
                    "citations": [top["id"]],
                    "matches": evidence["matches"],
                }
            report["mutating_actions"] = []
            return Response(message=Message(role="assistant", content=json.dumps(report)))
        return Response(message=Message(role="assistant", tool_calls=[
            ToolCall(id="search-1", name="search_documents",
                     arguments={"query": self.query, "scope": self.scope}),
        ]))


class SearchTool:
    name = "search_documents"
    description = "Search the fixed office policy fixtures; no arbitrary files or connectors."
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
            raise RuntimeError("simulated document index unavailable")
        query = str(args.get("query", ""))
        tokens = re.findall(r"[a-z]+", query.lower())
        matches = []
        for doc_id, text in DOCUMENTS.items():
            lowered = text.lower()
            score = sum(1 for token in tokens if token in lowered)
            if score:
                matches.append({"id": doc_id, "score": score, "snippet": text[:180]})
        matches.sort(key=lambda item: (-item["score"], item["id"]))
        return {"scope": "public", "matches": matches[:2]}


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind == "tool.invoke":
        return Decision(
            allowed=action.tool_name == "search_documents"
            and action.arguments.get("scope") == "public",
            reason="only public office fixtures are readable",
        )
    return Decision(allowed=False, reason="unsupported action")


async def run_qa(query: str, scope: str = "public", simulate_failure: bool = False, model=None):
    tool = SearchTool(simulate_failure=simulate_failure)
    tools = Registry()
    tools.register(tool)
    agent = Agent(AgentOptions(
        model=model or FixtureModel(query, scope),
        tools=tools,
        max_steps=3,
        allowed_tools=["search_documents"],
        policy=FuncHook(authorize),
    ))
    try:
        result = await agent.run(Session(id="office-qa"), f"Answer from public policy: {query}")
        return result.output, tool.calls, None
    except Exception as error:
        return "", tool.calls, error


def run_tests() -> None:
    output, calls, error = asyncio.run(run_qa("travel approval"))
    if error or calls != 1:
        raise RuntimeError(f"success failed: calls={calls} error={error}")
    report = json.loads(output)
    if report["citations"] != ["handbook"] or "manager approval" not in report["answer"]:
        raise RuntimeError(f"unexpected answer: {report}")
    if report["mutating_actions"]:
        raise RuntimeError("unexpected mutating action")

    _, calls, error = asyncio.run(run_qa("travel approval", scope="private"))
    if not isinstance(error, PolicyDeniedError) or calls != 0:
        raise RuntimeError(f"denial failed: calls={calls} error={error}")

    _, calls, error = asyncio.run(run_qa("travel approval", simulate_failure=True))
    if error is None or calls != 1:
        raise RuntimeError(f"dependency failure failed: calls={calls} error={error}")

    print("Python office-qa tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", default="travel approval")
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
    output, calls, error = asyncio.run(run_qa(
        args.query, args.scope, args.simulate_failure, model=model))
    if error:
        print(f"office qa failed: reads={calls}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
