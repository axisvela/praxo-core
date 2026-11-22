from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.middleware import StructuredOutput
from praxo.model import Message, Response

DOCUMENT_SCHEMA = {
    "type": "object",
    "required": ["title", "summary", "tags"],
    "properties": {
        "title": {"type": "string"},
        "summary": {"type": "string"},
        "tags": {"type": "array", "items": {"type": "string"}},
    },
}


class FixtureModel:
    async def generate(self, request):
        text = request.messages[-1].content if request.messages else ""
        if "invalid" in text.lower():
            content = json.dumps({"title": "Incomplete"})
        else:
            first = text.strip().splitlines()[0][:60] if text.strip() else "Untitled"
            content = json.dumps(
                {
                    "title": first,
                    "summary": text.strip()[:160],
                    "tags": ["triage"],
                }
            )
        return Response(message=Message(role="assistant", content=content))


async def triage(text: str, model) -> str:
    agent = Agent(
        AgentOptions(
            model=model,
            system_prompt=(
                "Turn the document into JSON with title, summary, and tags. "
                "Return only JSON."
            ),
            structured_output=StructuredOutput(schema=DOCUMENT_SCHEMA, name="document"),
        )
    )
    result = await agent.run(Session(id="structured-output-app"), text)
    return result.output


def append_jsonl(path: Path, record: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def completed_sources(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    sources = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        source = record.get("source")
        if source:
            sources.add(source)
    return sources


async def process_directory(
    input_dir: Path,
    output: Path,
    errors: Path,
    model,
    resume: bool = False,
) -> dict[str, int]:
    inputs = sorted(input_dir.glob("*.txt"))
    completed = completed_sources(output) if resume else set()
    counts = {"processed": 0, "skipped": 0, "failed": 0}
    for path in inputs:
        if path.name in completed:
            counts["skipped"] += 1
            continue
        text = path.read_text(encoding="utf-8").strip()
        try:
            output_json = await triage(text, model)
        except Exception as error:
            append_jsonl(
                errors,
                {
                    "source": path.name,
                    "error": type(error).__name__,
                    "detail": str(error),
                },
            )
            counts["failed"] += 1
            continue
        append_jsonl(output, {"source": path.name, "result": json.loads(output_json)})
        counts["processed"] += 1
    return counts


def build_model(args: argparse.Namespace):
    if not args.live:
        return FixtureModel()
    return OpenAICompatibleModel(
        OpenAIConfig(
            base_url=args.base_url,
            api_key=args.api_key,
            model=args.model,
        )
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Turn text files into validated JSON.")
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("out/results.jsonl"))
    parser.add_argument("--errors", type=Path, default=Path("out/errors.jsonl"))
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--live", action="store_true")
    parser.add_argument(
        "--base-url",
        default=os.getenv("PRAXO_BASE_URL", "http://localhost:11434/v1"),
    )
    parser.add_argument("--model", default=os.getenv("PRAXO_MODEL", "llama3.2"))
    parser.add_argument("--api-key", default=os.getenv("PRAXO_API_KEY", ""))
    args = parser.parse_args(argv)
    counts = asyncio.run(
        process_directory(
            args.input_dir,
            args.output,
            args.errors,
            build_model(args),
            resume=args.resume,
        )
    )
    print(
        f"processed={counts['processed']} skipped={counts['skipped']} "
        f"failed={counts['failed']}"
    )
    return 1 if counts["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
