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

PROJECT_ID = "project-100"


class FixtureModel:
    def __init__(self, project: str):
        self.project = project

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="tasks-1", name="read_tasks",
                         arguments={"project_id": self.project}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="plan-1", name="draft_plan",
                         arguments={"project_id": self.project, "action": "draft_coordination"}),
            ]))
        tasks = json.loads(tool_messages[0].content)
        plan = json.loads(tool_messages[-1].content)
        report = {
            "tasks": tasks,
            "plan": plan,
            "validity_claims": 0,
            "external_calls": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadTasksTool:
    name = "read_tasks"
    description = "Read fixed literature/simulation/review tasks within a shared budget."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["project_id"],
        "properties": {"project_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("project_id") != PROJECT_ID:
            raise ValueError("project outside fixture")
        if self.simulate_failure:
            raise RuntimeError("PROJECT_INDEX_UNAVAILABLE")
        return {
            "project_id": PROJECT_ID,
            "tasks": 3,
            "kinds": ["literature", "simulation", "review"],
            "budget_minutes": 60,
            "provenance": ["paper-1", "sim-1"],
            "source": "project_fixture",
        }


class DraftPlanTool:
    name = "draft_plan"
    description = "Draft a review-only coordination plan; never claims scientific validity."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["project_id", "action"],
        "properties": {
            "project_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "plan_id": "virtual-pi-100",
            "project_id": args.get("project_id"),
            "action": args.get("action"),
            "stages": 3,
            "shared_budget_minutes": 60,
            "provenance": ["paper-1", "sim-1"],
            "status": "draft_only",
            "review_required": True,
            "validity_claims": 0,
            "external_calls": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "read_tasks":
        return Decision(
            allowed=action.arguments.get("project_id") == PROJECT_ID,
            reason="only project-100 is in scope",
        )
    if action.tool_name == "draft_plan":
        return Decision(
            allowed=action.arguments.get("project_id") == PROJECT_ID
            and action.arguments.get("action") == "draft_coordination",
            reason="only a review-only coordination draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_project(project: str = PROJECT_ID, simulate_failure: bool = False):
    tasks = ReadTasksTool(simulate_failure=simulate_failure)
    draft = DraftPlanTool()
    tools = Registry()
    tools.register(tasks)
    tools.register(draft)
    agent = Agent(AgentOptions(
        model=FixtureModel(project),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_tasks", "draft_plan"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="virtual-pi"),
                                 "Coordinate the fixed research tasks and draft a review-only plan.")
        return result.output, tasks.calls, draft.calls, None
    except Exception as error:
        return "", tasks.calls, draft.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_project())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["tasks"]["budget_minutes"] != 60 or report["tasks"]["tasks"] != 3:
        raise RuntimeError(f"unexpected tasks: {report}")
    if report["plan"]["status"] != "draft_only" or report["validity_claims"] != 0 \
            or report["external_calls"] != 0:
        raise RuntimeError(f"unexpected plan: {report}")

    _, reads, drafts, error = asyncio.run(run_project("project-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_project(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python OG-07 virtual-pi tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=PROJECT_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_project(args.project, args.simulate_failure))
    if error:
        print(f"virtual PI failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
