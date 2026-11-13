import asyncio
import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

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


def create_agent(model=None) -> Agent:
    selected = model or OpenAICompatibleModel(
        OpenAIConfig(
            base_url=os.getenv("PRAXO_BASE_URL", "http://localhost:11434/v1"),
            api_key=os.getenv("PRAXO_API_KEY", ""),
            model=os.getenv("PRAXO_MODEL", "llama3.2"),
        )
    )
    tools = Registry()
    tools.register(
        FuncTool(
            "get_time",
            "Return the current UTC time in ISO 8601 format.",
            lambda _args: datetime.now(timezone.utc).isoformat(),
        )
    )
    return Agent(
        AgentOptions(
            model=selected,
            tools=tools,
            system_prompt="You are a concise service assistant. Use tools when they help.",
            max_steps=4,
            allowed_tools=["get_time"],
            policy=FuncHook(authorize),
        )
    )


def run_prompt(agent: Agent, principal: str, prompt: str) -> str:
    result = asyncio.run(
        agent.run(
            Session(id=principal, tenant_id=os.getenv("PRAXO_TENANT", "local")),
            prompt,
        )
    )
    return result.output


def make_handler(agent: Agent):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path == "/healthz":
                self._write(200, {"status": "ok"})
                return
            self._write(404, {"error": "not found"})

        def do_POST(self) -> None:
            if self.path != "/run":
                self._write(404, {"error": "not found"})
                return
            principal = self.headers.get("X-Praxo-Principal", "")
            if not principal:
                self._write(401, {"error": "missing X-Praxo-Principal"})
                return
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 65536:
                self._write(400, {"error": "invalid body"})
                return
            try:
                payload = json.loads(self.rfile.read(length))
                prompt = payload.get("prompt", "")
            except (ValueError, AttributeError):
                self._write(400, {"error": "invalid JSON body"})
                return
            if not prompt:
                self._write(400, {"error": "prompt is required"})
                return
            try:
                output = run_prompt(agent, principal, prompt)
            except Exception as error:
                self._write(500, {"error": str(error)})
                return
            self._write(200, {"output": output})

        def log_message(self, format: str, *args) -> None:
            return

        def _write(self, status: int, body: dict) -> None:
            encoded = json.dumps(body).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

    return Handler


def serve(host: str = "127.0.0.1", port: int = 8080) -> None:
    server = ThreadingHTTPServer((host, port), make_handler(create_agent()))
    print(f"listening on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    serve()
