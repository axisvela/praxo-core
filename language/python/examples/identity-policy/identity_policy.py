import asyncio
from dataclasses import dataclass

from praxo.agent import Agent, AgentOptions, Session
from praxo.model import Message, Response, ToolCall
from praxo.policy import Action, Decision, FuncHook
from praxo.tool import FuncTool, Registry

SESSION_ID = "session-1"


@dataclass
class Principal:
    id: str
    tenant: str
    role: str
    active: bool = True


class PrincipalStore:
    def __init__(self) -> None:
        self._principals: dict[str, Principal] = {}

    def bind(self, session_id: str, principal: Principal) -> None:
        self._principals[session_id] = principal

    def lookup(self, session_id: str) -> Principal | None:
        return self._principals.get(session_id)


class RecordingTool:
    def __init__(self) -> None:
        self.calls = 0

    async def invoke(self, args):
        self.calls += 1
        return "recorded"


def authorize(store: PrincipalStore, action: Action) -> Decision:
    principal = store.lookup(action.session_id)
    if principal is None:
        return Decision(False, "trusted principal is missing")
    if not principal.active:
        return Decision(False, "trusted principal is inactive")
    if action.kind == "model.generate":
        return Decision(True, "principal may run the agent")
    if action.kind != "tool.invoke":
        return Decision(False, "unsupported action")
    if principal.role != "operator":
        return Decision(False, "role is not permitted")
    claimed_tenant = (action.arguments or {}).get("tenant")
    if claimed_tenant != principal.tenant:
        return Decision(False, "tenant does not match the principal")
    if action.tool_name != "record":
        return Decision(False, "operation is not permitted")
    return Decision(True, "verified operator")


class ClaimingModel:
    def __init__(self, tenant: str, role: str) -> None:
        self.tenant = tenant
        self.role = role

    async def generate(self, request):
        if request.messages and request.messages[-1].role == "tool":
            return Response(message=Message(role="assistant", content="recorded"))
        return Response(
            message=Message(
                role="assistant",
                tool_calls=[
                    ToolCall(
                        id="record-1",
                        name="record",
                        arguments={
                            "tenant": self.tenant,
                            "role": self.role,
                        },
                    )
                ],
            )
        )


def run_case(
    principal: Principal | None,
    claimed_tenant: str = "acme",
    claimed_role: str = "admin",
) -> tuple[int, Exception | None]:
    store = PrincipalStore()
    if principal is not None:
        store.bind(SESSION_ID, principal)
    tool = RecordingTool()
    tools = Registry()
    tools.register(FuncTool("record", "Record a target.", tool.invoke))
    agent = Agent(
        AgentOptions(
            model=ClaimingModel(claimed_tenant, claimed_role),
            tools=tools,
            policy=FuncHook(lambda action: authorize(store, action)),
            allowed_tools=["record"],
            max_steps=3,
        )
    )
    try:
        result = asyncio.run(agent.run(Session(id=SESSION_ID), "record"))
    except Exception as error:
        return tool.calls, error
    return tool.calls, None if result.output == "recorded" else RuntimeError(result.output)


if __name__ == "__main__":
    raise SystemExit(
        "This example is runnable through its test; bind principals in identity_policy.py."
    )
