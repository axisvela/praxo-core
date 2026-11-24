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

MEDIA_ID = "media-100"


class FixtureModel:
    def __init__(self, media: str):
        self.media = media

    async def generate(self, request):
        tool_messages = [m for m in request.messages if m.role == "tool"]
        if not tool_messages:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="media-1", name="read_media",
                         arguments={"media_id": self.media}),
            ]))
        if len(tool_messages) == 1:
            return Response(message=Message(role="assistant", tool_calls=[
                ToolCall(id="caption-1", name="draft_caption_plan",
                         arguments={"media_id": self.media, "action": "draft_caption_plan"}),
            ]))
        media = json.loads(tool_messages[0].content)
        plan = json.loads(tool_messages[-1].content)
        report = {
            "media": media,
            "plan": plan,
            "voice_clones": 0,
            "lip_sync_claims": 0,
        }
        return Response(message=Message(role="assistant", content=json.dumps(report)))


class ReadMediaTool:
    name = "read_media"
    description = "Read fixed licensed media segments and timing limits; no audio synthesis."
    risk = "read"
    parameters = {
        "type": "object",
        "required": ["media_id"],
        "properties": {"media_id": {"type": "string"}},
    }

    def __init__(self, simulate_failure: bool = False):
        self.calls = 0
        self.simulate_failure = simulate_failure

    async def invoke(self, args):
        self.calls += 1
        if args.get("media_id") != MEDIA_ID:
            raise ValueError("media outside fixture")
        if self.simulate_failure:
            raise RuntimeError("MEDIA_INDEX_UNAVAILABLE")
        return {
            "media_id": MEDIA_ID,
            "segments": 4,
            "target_languages": ["ja"],
            "consent": "licensed",
            "max_caption_s": 0.8,
            "source": "media_fixture",
        }


class DraftCaptionPlanTool:
    name = "draft_caption_plan"
    description = "Draft a review-only caption and timing plan; never clones a voice."
    risk = "write"
    parameters = {
        "type": "object",
        "required": ["media_id", "action"],
        "properties": {
            "media_id": {"type": "string"},
            "action": {"type": "string"},
        },
    }

    def __init__(self):
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return {
            "plan_id": "dub-plan-100",
            "media_id": args.get("media_id"),
            "action": args.get("action"),
            "captions": 4,
            "status": "draft_only",
            "review_required": True,
            "voice_clones": 0,
            "lip_sync_claims": 0,
        }


def authorize(action):
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind != "tool.invoke":
        return Decision(allowed=False, reason="unsupported action")
    if action.tool_name == "read_media":
        return Decision(
            allowed=action.arguments.get("media_id") == MEDIA_ID,
            reason="only media-100 is in scope",
        )
    if action.tool_name == "draft_caption_plan":
        return Decision(
            allowed=action.arguments.get("media_id") == MEDIA_ID
            and action.arguments.get("action") == "draft_caption_plan",
            reason="only a review-only caption plan is allowed",
        )
    return Decision(allowed=False, reason="unsupported tool")


async def run_dubbing(media: str = MEDIA_ID, simulate_failure: bool = False):
    reader = ReadMediaTool(simulate_failure=simulate_failure)
    draft = DraftCaptionPlanTool()
    tools = Registry()
    tools.register(reader)
    tools.register(draft)
    agent = Agent(AgentOptions(
        model=FixtureModel(media),
        tools=tools,
        max_steps=4,
        allowed_tools=["read_media", "draft_caption_plan"],
        policy=FuncHook(authorize),
        require_policy=True,
        require_tool_scope=True,
    ))
    try:
        result = await agent.run(Session(id="dubbing-plan"),
                                 "Read the fixed media and draft a caption plan.")
        return result.output, reader.calls, draft.calls, None
    except Exception as error:
        return "", reader.calls, draft.calls, error


def run_tests() -> None:
    output, reads, drafts, error = asyncio.run(run_dubbing())
    if error or reads != 1 or drafts != 1:
        raise RuntimeError(f"success failed: reads={reads} drafts={drafts} error={error}")
    report = json.loads(output)
    if report["media"]["consent"] != "licensed" or report["media"]["segments"] != 4:
        raise RuntimeError(f"unexpected media: {report}")
    if report["plan"]["status"] != "draft_only" or report["voice_clones"] != 0 \
            or report["lip_sync_claims"] != 0:
        raise RuntimeError(f"unexpected plan: {report}")

    _, reads, drafts, error = asyncio.run(run_dubbing("media-200"))
    if not isinstance(error, PolicyDeniedError) or reads != 0 or drafts != 0:
        raise RuntimeError(f"denial failed: reads={reads} drafts={drafts} error={error}")

    _, reads, drafts, error = asyncio.run(run_dubbing(simulate_failure=True))
    if error is None or reads != 1 or drafts != 0:
        raise RuntimeError(f"dependency failure failed: reads={reads} drafts={drafts}")

    print("Python MD-04 dubbing-plan tutorial: all checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--media", default=MEDIA_ID)
    parser.add_argument("--simulate-failure", action="store_true")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args(argv)
    if args.test:
        run_tests()
        return 0
    output, reads, drafts, error = asyncio.run(run_dubbing(args.media, args.simulate_failure))
    if error:
        print(f"dubbing plan failed: reads={reads} drafts={drafts}; {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
