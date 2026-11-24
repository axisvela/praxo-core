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

REPO_ID = "repo-100"
SOURCE = """def parse_offset(text):
    hours, minutes = text.split(':')
    return 0
"""


class FixtureModel:
    def __init__(self, repo: str):
        self.repo = repo

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="defect-1", name="read_defect",
                         arguments={"repo_id": self.repo}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="patch-1", name="draft_patch",
                         arguments={"repo_id": self.repo, "action": "draft_patch"}),
            ]))
        if len(tool_messages) == 2:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="tests-1", name="run_tests",
                         arguments={"repo_id": self.repo, "action": "run_tests"}),
            ]))
        defect = json.loads(tool_messages[0].content)
        patch = json.loads(tool_messages[1].content)
        tests = json.loads(tool_messages[-1].content)
        report = {
            "defect": defect,
            "patch": patch,
            "tests": tests,
            "pull_requests": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadDefectTool:
    name = "read_defect"
    description = "Read a seeded defect and its failing test; no repository scan."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["repo_id"],
        "properties": {"repo_id": {"type": "string"}},
    }

    def __init__(self, source: dict, simulate_failure: bool = False):
        self.source = source
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("repo_id") != REPO_ID:
            raise ValueError("repository outside fixture")
        if self.simulate_failure:
            raise RuntimeError("REPOSITORY_UNAVAILABLE")
        return {
            "repo_id": REPO_ID,
            "file": "offset.py",
            "source": self.source["text"],
            "failing_test": "test_parse_offset expects 90 for '1:30'",
            "observed": 0,
            "source_kind": "fixture",
        }


class DraftPatchTool:
    name = "draft_patch"
    description = "Apply a review-only patch to the in-memory fixture; no commit."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["repo_id", "action"],
        "properties": {
            "repo_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self, source: dict):
        self.source = source
        self.calls = 0
        self.patch = ""

    async def invoke(self, args):
        self.calls += 1
        self.patch = (
            "--- a/offset.py\n"
            "+++ b/offset.py\n"
            "@@\n"
            "-    return 0\n"
            "+    return int(hours) * 60 + int(minutes)\n"
        )
        self.source["text"] = self.source["text"].replace(
            "    return 0\n",
            "    return int(hours) * 60 + int(minutes)\n",
        )
        return {
            "patch_id": "patch-100",
            "repo_id": args.get("repo_id"),
            "file": "offset.py",
            "action": args.get("action"),
            "patch": self.patch,
            "changed_lines": 1,
            "status": "draft_only",
            "review_required": True,
            "pull_requests": 0,
        }


class RunTestsTool:
    name = "run_tests"
    description = "Rerun the fixture test against the patched source; no real test runner."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["repo_id", "action"],
        "properties": {
            "repo_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self, source: dict):
        self.source = source
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        passed = "int(hours) * 60 + int(minutes)" in self.source["text"]
        return {
            "repo_id": args.get("repo_id"),
            "action": args.get("action"),
            "before": "failed",
            "after": "passed" if passed else "failed",
            "passed": passed,
            "test_runs": 1,
            "pull_requests": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.arguments.get("repo_id") != REPO_ID:
        return Decision(allowed=False, reason="only repo-100 is in scope")
    if action.tool_name in ("read_defect", "draft_patch", "run_tests"):
        required = {
            "read_defect": None,
            "draft_patch": "draft_patch",
            "run_tests": "run_tests",
        }[action.tool_name]
        if required and action.arguments.get("action") != required:
            return Decision(allowed=False, reason="unexpected action")
        return Decision(allowed=True, reason="review-only bug repair fixture")
    return Decision(allowed=False, reason="unsupported tool")


async def run_repair(repo: str = REPO_ID, simulate_failure: bool = False):
    source = {"text": SOURCE}
    read = ReadDefectTool(source, simulate_failure=simulate_failure)
    patch = DraftPatchTool(source)
    tests = RunTestsTool(source)
    tools = Registry()
    tools.register(read)
    tools.register(patch)
    tools.register(tests)
    agent = Agent(AgentOptions(
        model=FixtureModel(repo),
        tools=tools,
        max_steps=5,
        allowed_tools=["read_defect", "draft_patch", "run_tests"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="bug-repair"),
                                 "Reproduce the fixed defect, draft a patch and rerun tests.")
        return result.output, read.calls, patch.calls, tests.calls, None
    except Exception as error:
        return "", read.calls, patch.calls, tests.calls, error


def run_tests() -> None:
    output, reads, patches, runs, error = asyncio.run(run_repair())
    if error or (reads, patches, runs) != (1, 1, 1):
        raise RuntimeError(f"success failed: {reads=} {patches=} {runs=} {error=}")
    report = json.loads(output)
    if report["defect"]["observed"] != 0:
        raise RuntimeError(f"unexpected defect: {report}")
    if report["patch"]["changed_lines"] != 1 or report["patch"]["status"] != "draft_only":
        raise RuntimeError(f"unexpected patch: {report}")
    if report["tests"]["before"] != "failed" or report["tests"]["passed"] is not True:
        raise RuntimeError(f"unexpected tests: {report}")
    if report["pull_requests"] != 0:
        raise RuntimeError(f"unexpected PR: {report}")

    _, reads, patches, runs, error = asyncio.run(run_repair("repo-200"))
    if not isinstance(error, PolicyDeniedError) or (reads, patches, runs) != (0, 0, 0):
        raise RuntimeError(f"denial failed: {reads=} {patches=} {runs=} {error=}")

    _, reads, patches, runs, error = asyncio.run(run_repair(simulate_failure=True))
    if error is None or (reads, patches, runs) != (1, 0, 0):
        raise RuntimeError(f"dependency failure failed: {reads=} {patches=} {runs=}")

    print("Python SE-02 bug-repair tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=REPO_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, patches, runs, error = asyncio.run(
        run_repair(args.repo, args.simulate_failure))
    if error:
        print(f"bug repair failed: reads={reads} patches={patches} runs={runs}; {error}",
              file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
