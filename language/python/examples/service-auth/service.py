import argparse
import asyncio
import base64
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.agent import Agent, AgentOptions, Session
from praxo.checkpoint import Checkpoint, Message as CheckpointMessage
from praxo.errors import PolicyDeniedError
from praxo.policy import Action, Decision, FuncHook
from praxo.tool import FuncTool, Registry

from identity import AuthError, Principal, PrincipalStore
from introspection import IntrospectionVerifier, revoke_token
from oidc import OidcVerifier


class RemotePolicy:
    def __init__(self, url: str, timeout: float = 2.0) -> None:
        self.url = url
        self.timeout = timeout

    def decide(self, principal: Principal, action: Action) -> Decision:
        payload = {
            "principal": {
                "subject": principal.subject,
                "tenant": principal.tenant,
            },
            "action": {
                "kind": action.kind,
                "tool_name": action.tool_name or "",
                "arguments": action.arguments,
            },
        }
        try:
            request = urllib.request.Request(
                self.url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                if response.status != 200:
                    return Decision(False, "policy service returned an error")
                body = json.loads(response.read())
        except Exception:
            return Decision(False, "policy service unavailable")
        if not isinstance(body, dict) or not isinstance(body.get("allowed"), bool):
            return Decision(False, "policy service returned an invalid decision")
        reason = body.get("reason")
        return Decision(
            body["allowed"],
            reason if isinstance(reason, str) else "",
        )


class FileCheckpointStore:
    def __init__(self, directory: str | Path) -> None:
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)

    def save(self, checkpoint: Checkpoint) -> None:
        name = "".join(
            character
            if character.isalnum() or character in "-_."
            else "_"
            for character in checkpoint.run_id
        )
        path = self.directory / f"{name or 'checkpoint'}.json"
        temp = path.with_suffix(".tmp")
        payload = {
            "id": checkpoint.id,
            "session_id": checkpoint.session_id,
            "run_id": checkpoint.run_id,
            "status": checkpoint.status,
            "tenant_id": checkpoint.tenant_id,
            "workspace_id": checkpoint.workspace_id,
            "messages": [message.to_wire() for message in checkpoint.messages],
            "created_at": (
                checkpoint.created_at.isoformat()
                if checkpoint.created_at is not None
                else None
            ),
        }
        temp.write_text(
            json.dumps(payload, separators=(",", ":"), sort_keys=True),
            encoding="utf-8",
        )
        os.replace(temp, path)


def parse_tenants(value: str) -> set[str]:
    return {item.strip() for item in value.split(",") if item.strip()}


def sign_token(
    secret: str,
    subject: str,
    tenant: str,
    expires: int | float,
) -> str:
    payload = json.dumps(
        {"sub": subject, "tenant": tenant, "exp": int(expires)},
        separators=(",", ":"),
    ).encode("utf-8")
    encoded = base64.urlsafe_b64encode(payload).rstrip(b"=").decode("ascii")
    signature = hmac.new(
        secret.encode("utf-8"),
        encoded.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    return f"{encoded}.{signature}"


def verify_bearer(
    header: str,
    secret: str,
    now: int | None = None,
) -> Principal:
    if not header.startswith("Bearer "):
        raise AuthError("missing bearer token")
    token = header.removeprefix("Bearer ")
    parts = token.split(".")
    if len(parts) != 2:
        raise AuthError("invalid token")
    payload_part, signature_part = parts
    try:
        signature = bytes.fromhex(signature_part)
    except ValueError as error:
        raise AuthError("invalid token signature") from error
    expected = hmac.new(
        secret.encode("utf-8"),
        payload_part.encode("ascii"),
        hashlib.sha256,
    ).digest()
    if not hmac.compare_digest(signature, expected):
        raise AuthError("invalid token signature")
    padding = "=" * (-len(payload_part) % 4)
    try:
        payload = json.loads(
            base64.urlsafe_b64decode(payload_part + padding).decode("utf-8")
        )
    except (ValueError, UnicodeDecodeError) as error:
        raise AuthError("invalid token claims") from error
    if not isinstance(payload, dict):
        raise AuthError("invalid token claims")
    subject = payload.get("sub")
    tenant = payload.get("tenant")
    expires = payload.get("exp")
    if not isinstance(subject, str) or not subject:
        raise AuthError("token is missing subject")
    if not isinstance(tenant, str) or not tenant:
        raise AuthError("token is missing tenant")
    if not isinstance(expires, int) or isinstance(expires, bool):
        raise AuthError("token is missing expiration")
    current = int(time.time()) if now is None else now
    if expires <= current:
        raise AuthError("token is expired")
    return Principal(subject, tenant, expires)


def authorize(
    store: PrincipalStore,
    allowed_tenants: set[str],
    action: Action,
    remote_policy: RemotePolicy | None = None,
) -> Decision:
    principal = store.lookup(action.session_id)
    if principal is None:
        return Decision(False, "trusted principal is missing")
    if principal.expires <= int(time.time()):
        return Decision(False, "trusted principal is expired")
    if principal.tenant not in allowed_tenants:
        return Decision(False, "tenant is not allowed")
    if remote_policy is not None:
        remote = remote_policy.decide(principal, action)
        if not remote.allowed:
            return remote
    if action.kind == "model.generate":
        return Decision(True, "principal may run the agent")
    if action.kind != "tool.invoke":
        return Decision(False, "unsupported action")
    if action.tool_name != "get_time":
        return Decision(False, "only get_time is permitted")
    return Decision(True, "verified principal")


def create_agent(
    model=None,
    allowed_tenants: set[str] | None = None,
    store: PrincipalStore | None = None,
    remote_policy: RemotePolicy | None = None,
) -> Agent:
    selected = model or OpenAICompatibleModel(
        OpenAIConfig(
            base_url=os.getenv("PRAXO_BASE_URL", "http://localhost:11434/v1"),
            api_key=os.getenv("PRAXO_API_KEY", ""),
            model=os.getenv("PRAXO_MODEL", "llama3.2"),
        )
    )
    principals = store or PrincipalStore()
    allowed = (
        allowed_tenants
        if allowed_tenants is not None
        else parse_tenants(os.getenv("PRAXO_ALLOWED_TENANTS", "local"))
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
            policy=FuncHook(
                lambda action: authorize(
                    principals,
                    allowed,
                    action,
                    remote_policy,
                )
            ),
            require_policy=True,
            require_tool_scope=True,
        )
    )


def run_prompt(
    agent: Agent,
    principal: Principal,
    prompt: str,
    store: FileCheckpointStore | None = None,
) -> str:
    async def _run() -> str:
        result = await agent.run(
            Session(
                id=principal.session_id,
                tenant_id=principal.tenant,
                workspace_id="service",
            ),
            prompt,
        )
        if store is not None:
            store.save(
                Checkpoint(
                    id=result.run_id,
                    session_id=principal.session_id,
                    run_id=result.run_id,
                    status="completed",
                    tenant_id=principal.tenant,
                    workspace_id="service",
                    messages=[
                        CheckpointMessage(role="assistant", content=result.output)
                    ],
                    created_at=datetime.now(timezone.utc),
                )
            )
        return result.output

    return asyncio.run(_run())


def make_handler(
    agent: Agent,
    secret: str,
    allowed_tenants: set[str],
    store: PrincipalStore,
    checkpoint_store: FileCheckpointStore | None = None,
    authenticator=None,
):
    verify = authenticator or (lambda header: verify_bearer(header, secret))

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
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                self._write(400, {"error": "invalid body"})
                return
            if length <= 0 or length > 65536:
                self._write(400, {"error": "invalid body"})
                return
            raw_body = self.rfile.read(length)
            try:
                principal = verify(
                    self.headers.get("Authorization", ""),
                )
            except AuthError as error:
                self._write(401, {"error": str(error)})
                return
            if principal.tenant not in allowed_tenants:
                self._write(403, {"error": "tenant is not allowed"})
                return
            try:
                payload = json.loads(raw_body)
            except (ValueError, AttributeError):
                self._write(400, {"error": "invalid JSON body"})
                return
            if not isinstance(payload, dict):
                self._write(400, {"error": "invalid JSON body"})
                return
            prompt = payload.get("prompt")
            if not isinstance(prompt, str) or not prompt:
                self._write(400, {"error": "prompt is required"})
                return
            store.bind(principal)
            try:
                output = run_prompt(
                    agent,
                    principal,
                    prompt,
                    checkpoint_store,
                )
            except PolicyDeniedError as error:
                self._write(403, {"error": str(error)})
                return
            except Exception as error:
                print(f"run error: {error}", file=sys.stderr, flush=True)
                self._write(500, {"error": "agent run failed"})
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


def create_authenticator():
    issuer = os.getenv("PRAXO_OIDC_ISSUER", "")
    timeout = float(os.getenv("PRAXO_OIDC_TIMEOUT", "2"))
    tenant_claim = os.getenv("PRAXO_OIDC_TENANT_CLAIM", "tenant")
    discovery_url = os.getenv("PRAXO_OIDC_DISCOVERY_URL", "")
    introspection_url = os.getenv("PRAXO_INTROSPECTION_URL", "")
    client_id = os.getenv("PRAXO_INTROSPECTION_CLIENT_ID", "") or os.getenv(
        "PRAXO_OIDC_CLIENT_ID", ""
    )
    client_secret = os.getenv(
        "PRAXO_INTROSPECTION_CLIENT_SECRET", ""
    ) or os.getenv("PRAXO_OIDC_CLIENT_SECRET", "")
    if introspection_url:
        return IntrospectionVerifier(
            url=introspection_url,
            issuer=issuer,
            discovery_url=discovery_url,
            client_id=client_id,
            client_secret=client_secret,
            tenant_claim=tenant_claim,
            timeout=timeout,
        ).verify
    if issuer:
        audience = os.getenv("PRAXO_OIDC_AUDIENCE", "")
        if not audience:
            raise SystemExit("PRAXO_OIDC_AUDIENCE is required")
        jwks_url = os.getenv("PRAXO_OIDC_JWKS_URL", "")
        verifier = OidcVerifier(
            issuer,
            audience,
            jwks_url=jwks_url,
            discovery_url=discovery_url,
            tenant_claim=tenant_claim,
            timeout=timeout,
        )
        return verifier.verify
    return None


def serve(host: str = "127.0.0.1", port: int = 8080) -> None:
    secret = os.getenv("PRAXO_SERVICE_SECRET", "")
    authenticator = create_authenticator()
    if authenticator is None and not secret:
        raise SystemExit(
            "PRAXO_SERVICE_SECRET or PRAXO_OIDC_ISSUER is required"
        )
    allowed = parse_tenants(os.getenv("PRAXO_ALLOWED_TENANTS", "local"))
    policy_url = os.getenv("PRAXO_POLICY_URL", "")
    remote_policy = (
        RemotePolicy(
            policy_url,
            float(os.getenv("PRAXO_POLICY_TIMEOUT", "2")),
        )
        if policy_url
        else None
    )
    principals = PrincipalStore()
    checkpoint_store = FileCheckpointStore(
        os.getenv("PRAXO_CHECKPOINT_DIR", "checkpoints")
    )
    server = ThreadingHTTPServer(
        (host, port),
        make_handler(
            create_agent(
                allowed_tenants=allowed,
                store=principals,
                remote_policy=remote_policy,
            ),
            secret,
            allowed,
            principals,
            checkpoint_store,
            authenticator=authenticator,
        ),
    )
    server.daemon_threads = True
    print(f"listening on http://{host}:{port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--addr", default="127.0.0.1:8080")
    parser.add_argument("--print-token", nargs=2, metavar=("SUBJECT", "TENANT"))
    parser.add_argument("--revoke-token", metavar="TOKEN")
    parser.add_argument("--ttl", type=int, default=3600)
    args = parser.parse_args()
    secret = os.getenv("PRAXO_SERVICE_SECRET", "")
    if args.revoke_token:
        revoke_token(
            args.revoke_token,
            url=os.getenv("PRAXO_REVOCATION_URL", ""),
            issuer=os.getenv("PRAXO_OIDC_ISSUER", ""),
            discovery_url=os.getenv("PRAXO_OIDC_DISCOVERY_URL", ""),
            client_id=os.getenv("PRAXO_INTROSPECTION_CLIENT_ID", "")
            or os.getenv("PRAXO_OIDC_CLIENT_ID", ""),
            client_secret=os.getenv(
                "PRAXO_INTROSPECTION_CLIENT_SECRET", ""
            )
            or os.getenv("PRAXO_OIDC_CLIENT_SECRET", ""),
            timeout=float(os.getenv("PRAXO_OIDC_TIMEOUT", "2")),
        )
        print("token revoked")
        return
    if args.print_token:
        if not secret:
            raise SystemExit("PRAXO_SERVICE_SECRET is required")
        subject, tenant = args.print_token
        print(sign_token(secret, subject, tenant, time.time() + args.ttl))
        return
    host, _, port = args.addr.rpartition(":")
    serve(host or "127.0.0.1", int(port))


if __name__ == "__main__":
    main()
