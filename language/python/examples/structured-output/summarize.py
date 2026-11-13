import asyncio
import json
import os
import sys

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.middleware import StructuredOutput

SUMMARY_SCHEMA = {
    "type": "object",
    "required": ["title", "summary", "tags"],
    "properties": {
        "title": {"type": "string"},
        "summary": {"type": "string"},
        "tags": {
            "type": "array",
            "items": {"type": "string"},
        },
    },
}


async def summarize(text: str, model=None) -> str:
    selected = model or OpenAICompatibleModel(
        OpenAIConfig(
            base_url=os.getenv("PRAXO_BASE_URL", "http://localhost:11434/v1"),
            api_key=os.getenv("PRAXO_API_KEY", ""),
            model=os.getenv("PRAXO_MODEL", "llama3.2"),
        )
    )
    agent = Agent(
        AgentOptions(
            model=selected,
            system_prompt=(
                "Summarize the supplied text as JSON with title, summary, and tags. "
                "Return only JSON."
            ),
            structured_output=StructuredOutput(
                schema=SUMMARY_SCHEMA,
                name="summary",
            ),
        )
    )
    result = await agent.run(Session(id="structured-output"), text)
    return result.output


def main() -> None:
    text = " ".join(sys.argv[1:]).strip() or sys.stdin.read().strip()
    if not text:
        raise SystemExit("usage: python summarize.py <text>")
    try:
        print(asyncio.run(summarize(text)))
    except Exception as error:
        raise SystemExit(
            "structured output run failed: "
            f"{error}\n\nCheck PRAXO_BASE_URL, PRAXO_MODEL, and PRAXO_API_KEY"
        ) from error


if __name__ == "__main__":
    main()
