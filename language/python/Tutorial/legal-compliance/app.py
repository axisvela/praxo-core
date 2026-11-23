from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import ApprovalDeniedError, PolicyDeniedError
from praxo.model import Message, Response, ToolCall
from praxo.policy import Decision, FuncHook
from praxo.tool import Registry

MEMO_ID = "memo-100"

POLICIES = {
    "retention": "Retention policy: customer records must be kept for seven years and deleted after that.",
    "privacy": "Personal data may only be processed with a documented lawful basis.",
    "audit": "Every access to regulated records must be logged and retained.",
}


class FixtureModel:
    def __init__(self, query: str, scope: str):
        self.query = query
        self.scope = scope

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="search-1", name="search_policy",
                         arguments={"query": self.query, "scope": self.scope}),
            ]))
        if len(tool_messages) == 1:
            evidence = json.loads(tool_messages[0].content)
            citations = [match["id"] for match in evidence.get("matches", [])[:1]]
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="publish-1", name="publish_memo",
                         arguments={"memo_id": MEMO_ID, "action": "publish",
                                    "citations": citations}),
            ]))
        published = json.loads(tool_messages[-1].content)
        report = {
            "memo_id": published["memo_id"],
            "status": published["status"],
            "citations": published["citations"],
            "publications": 1,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class SearchPolicyTool:
    name = "search_policy"
    description = "Search fixed compliance policy fixtures; no arbitrary files or connectors."
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
            raise RuntimeError("simulated policy index unavailable")
        tokens = re.findall(r"[a-z]+", str(args.get("query", "")).lower())
        matches = []
        for policy_id, text in POLICIES.items():
            lowered = text.lower()
            score = sum(1 for token in tokens if token in lowered)
            if score:
                matches.append({"id": policy_id, "score": score, "snippet": text})
        matches.sort(key=lambda item: (-item["score"], item["id"]))
        return {"scope": "public", "matches": matches[:2]}


class PublishMemoTool:
    name = "publish_memo"
    description = "Publish a compliance memo after human approval; simulated effect."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["memo_id", "action"],
        "properties": {
            "memo_id": {"type": "string"},
            "action": {"type": "string"},
            "citations": {"type": "array"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "memo_id": args.get("memo_id"),
            "status": "published",
            "action": args.get("action"),
            "citations": args.get("citations", []),
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind == "tool.invoke":
        if action.tool_name == "search_policy":
            return Decision(
                allowed=action.arguments.get("scope") == "public",
                reason="only public policy fixtures are readable",
            )
        if action.tool_name == "publish_memo":
            return Decision(
                allowed=action.arguments.get("action") == "publish",
                reason="only publish_memo with action=publish is allowed",
            )
    return Decision(allowed=False, reason="unsupported action")


async def run_memo(
    query: str = "retention",
    scope: str = "public",
    approve: bool = True,
    simulate_failure: bool = False,
    model=None,
):
    search = SearchPolicyTool(simulate_failure=simulate_failure)
    publish = PublishMemoTool()
    tools = Registry()
    tools.register(search)
    tools.register(publish)
    agent = Agent(AgentOptions(
        model=model or FixtureModel(query, scope),
        tools=tools,
        max_steps=4,
        allowed_tools=["search_policy", "publish_memo"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
        interrupt_on={"publish_memo"},
        on_interrupt=lambda interrupt: approve,
    ))
    try:
        result = await agent.run(Session(id="legal-compliance"), f"Draft and publish a memo about {query}.")
        return result.output, search.calls, publish.calls, None
    except Exception as error:
        return "", search.calls, publish.calls, error


def run_tests() -> None:
    output, reads, publications, error = asyncio.run(run_memo())
    if error or reads != 1 or publications != 1:
        raise RuntimeError(f"approve failed: reads={reads} pubs={publications} error={error}")
    report = json.loads(output)
    if report["status"] != "published" or report["citations"] != ["retention"]:
        raise RuntimeError(f"unexpected report: {report}")
    if report["publications"] != 1:
        raise RuntimeError(f"unexpected publication count: {report}")

    _, reads, publications, error = asyncio.run(run_memo(approve=False))
    if not isinstance(error, ApprovalDeniedError) or reads != 1 or publications != 0:
        raise RuntimeError(f"reject failed: reads={reads} pubs={publications} error={error}")

    _, reads, publications, error = asyncio.run(run_memo(scope="private"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or publications != 0:
        raise RuntimeError(f"denial failed: reads={reads} pubs={publications} error={error}")

    _, reads, publications, error = asyncio.run(run_memo(simulate_failure=True))
    if error is None or reads != 1 or publications != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} pubs={publications} error={error}")

    print("Python legal-compliance tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", default="retention")
    parser.add_argument("--scope", default="public")
    parser.add_argument("--reject", action="store_true", help="reject the publish approval")
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
    output, reads, publications, error = asyncio.run(run_memo(
        args.query, args.scope, not args.reject, args.simulate_failure, model=model))
    if error:
        print(
            f"legal memo failed: reads={reads} publications={publications}; {error}",
            file=sys.stderr,
        )
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
