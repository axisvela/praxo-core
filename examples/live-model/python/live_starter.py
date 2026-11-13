import asyncio
import os
from datetime import datetime, timezone

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.policy import Action, Decision, FuncHook
from praxo.tool import FuncTool, Registry


def authorize(action: Action) -> Decision:
    if action.kind == "model.generate":
        return Decision(allowed=True)
    if action.kind == "tool.invoke":
        return Decision(
            allowed=action.tool_name == "get_time",
            reason="only get_time is permitted",
        )
    return Decision(allowed=False, reason="unsupported action")


async def main() -> None:
    base_url = os.getenv("PRAXO_BASE_URL", "http://localhost:11434/v1")
    model_name = os.getenv("PRAXO_MODEL", "llama3.2")
    prompt = os.getenv(
        "PRAXO_PROMPT",
        "What time is it? Use the get_time tool and reply with the time.",
    )

    tools = Registry()
    tools.register(
        FuncTool(
            "get_time",
            "Return the current UTC time in ISO 8601 format.",
            lambda _args: datetime.now(timezone.utc).isoformat(),
        )
    )

    agent = Agent(
        AgentOptions(
            model=OpenAICompatibleModel(
                OpenAIConfig(
                    base_url=base_url,
                    api_key=os.getenv("PRAXO_API_KEY", ""),
                    model=model_name,
                )
            ),
            tools=tools,
            system_prompt="You are a concise assistant. Use the provided tools when they help.",
            max_steps=4,
            allowed_tools=["get_time"],
            policy=FuncHook(authorize),
        )
    )

    try:
        result = await agent.run(Session(id="live-model"), prompt)
    except Exception as error:
        raise SystemExit(
            "live model run failed: "
            f"{error}\n\nCheck PRAXO_BASE_URL ({base_url}), "
            f"PRAXO_MODEL ({model_name}), and PRAXO_API_KEY"
        ) from error
    print(result.output)


if __name__ == "__main__":
    asyncio.run(main())
