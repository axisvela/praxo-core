import asyncio

from praxo.agent import Agent, AgentOptions, Session


def create_agent(primary, fallback) -> Agent:
    return Agent(
        AgentOptions(
            model=primary,
            fallback_model=fallback,
            system_prompt="You are a concise assistant.",
            max_steps=2,
        )
    )


async def run(primary, fallback, prompt: str = "Say hello.") -> str:
    result = await create_agent(primary, fallback).run(
        Session(id="provider-fallback"),
        prompt,
    )
    return result.output


if __name__ == "__main__":
    raise SystemExit(
        "This example is runnable through its test; wire real model adapters in fallback.py."
    )
