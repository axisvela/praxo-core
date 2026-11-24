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

REGION_ID = "region-100"


class FixtureModel:
    def __init__(self, region: str):
        self.region = region

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="sensors-1", name="read_sensors",
                         arguments={"region_id": self.region}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="hypotheses-1", name="draft_hypotheses",
                         arguments={"region_id": self.region,
                                    "action": "draft_investigation"}),
            ]))
        sensors = json.loads(tool_messages[0].content)
        hypotheses = json.loads(tool_messages[-1].content)
        report = {
            "sensors": sensors,
            "hypotheses": hypotheses,
            "enforcement_findings": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadSensorsTool:
    name = "read_sensors"
    description = "Compare fixed sensor and weather records; no live monitoring."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["region_id"],
        "properties": {"region_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("region_id") != REGION_ID:
            raise ValueError("region outside fixture")
        if self.simulate_failure:
            raise RuntimeError("SENSOR_INDEX_UNAVAILABLE")
        return {
            "region_id": REGION_ID,
            "sensors": 3,
            "exceedances": 2,
            "wind": "north",
            "candidate_source": "plant-3",
            "source": "sensor_fixture",
        }


class DraftHypothesesTool:
    name = "draft_hypotheses"
    description = "Draft review-only investigation hypotheses; never an enforcement finding."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["region_id", "action"],
        "properties": {
            "region_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "investigation_id": "pollution-100",
            "region_id": args.get("region_id"),
            "action": args.get("action"),
            "hypotheses": [
                "Plant-3 emissions track north wind readings",
                "A sensor calibration drift is possible",
            ],
            "status": "draft_only",
            "review_required": True,
            "enforcement_findings": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "read_sensors":
        return Decision(
            allowed=action.arguments.get("region_id") == REGION_ID,
            reason="only region-100 is in scope",
        )
    if action.tool_name == "draft_hypotheses":
        return Decision(
            allowed=action.arguments.get("region_id") == REGION_ID
            and action.arguments.get("action") == "draft_investigation",
            reason="only a review-only investigation draft is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_tracing(region: str = REGION_ID, simulate_failure: bool = False):
    sensors = ReadSensorsTool(simulate_failure=simulate_failure)
    draft = DraftHypothesesTool()
    tools = Registry()
    tools.register(sensors)
    tools.register(draft)
    agent = Agent(AgentOptions(
        model=FixtureModel(region),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_sensors", "draft_hypotheses"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="pollution-tracing"),
                                 "Compare fixed records and draft investigation hypotheses.")
        return result.output, sensors.calls, draft.calls, None
    except Exception as error:
        return "", sensors.calls, draft.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_tracing())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["sensors"]["candidate_source"] != "plant-3":
        raise RuntimeError(f"unexpected sensors: {report}")
    if report["hypotheses"]["status"] != "draft_only" or report["enforcement_findings"] != 0:
        raise RuntimeError(f"unexpected hypotheses: {report}")

    _, reads, drafts, error = asyncio.run(run_tracing("region-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_tracing(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python CT-05 pollution-tracing tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--region", default=REGION_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_tracing(args.region, args.simulate_failure))
    if error:
        print(f"pollution tracing failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
