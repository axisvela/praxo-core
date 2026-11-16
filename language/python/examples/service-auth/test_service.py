import base64
import hashlib
import json
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from praxo.model import Message, Response
from praxo.policy import Action

from oidc import OidcVerifier
from service import (
    FileCheckpointStore,
    Principal,
    PrincipalStore,
    RemotePolicy,
    authorize,
    create_agent,
    make_handler,
    sign_token,
)


OIDC_ISSUER = "https://issuer.example.com"
OIDC_AUDIENCE = "praxo-service"
OIDC_KEY_ID = "test-key"
RSA_N = int.from_bytes(
    base64.urlsafe_b64decode(
        "ofgWCuLjybRlzo0tZWJjNiuSfb4p4fAkd_wWJcyQoTbji9k0l8W26mPddxHmfHQp-Vaw-4qPCJrcS2mJPMEzP1Pt0Bm4d4QlL-yRT-SFd2lZS-pCgNMsD1W_YpRPEwOWvG6b32690r2jZ47soMZo9wGzjb_7OMg0LOL-bSf63kpaSHSXndS5z5rexMdbBYUsLA9e-KXBdQOS-UTo7WTBEMa2R2CapHg665xsmtdVMTBQY4uDZlxvb3qCo5ZwKh9kG4LT6_I5IhlJH7aGhyxXFvUK-DWNmoudF8NAco9_h9iaGNj8q2ethFkMLs91kzk2PAcDTW9gb54h4FRWyuXpoQ"
        + "=="
    ),
    "big",
)
RSA_D = int.from_bytes(
    base64.urlsafe_b64decode(
        "Eq5xpGnNCivDflJsRQBXHx1hdR1k6Ulwe2JZD50LpXyWPEAeP88vLNO97IjlA7_GQ5sLKMgvfTeXZx9SE-7YwVol2NXOoAJe46sui395IW_GO-pWJ1O0BkTGoVEn2bKVRUCgu-GjBVaYLU6f3l9kJfFNS3E0QbVdxzubSu3Mkqzjkn439X0M_V51gfpRLI9JYanrC4D4qAdGcopV_0ZHHzQlBjudU2QvXt4ehNYTCBr6XCLQUShb1juUO1ZdiYoFaFQT5Tw8bGUl_x_jTj3ccPDVZFD9pIuhLhBOneufuBiB4cS98l2SR_RQyGWSeWjnczT0QU91p1DhOVRuOopznQ"
        + "=="
    ),
    "big",
)
RSA_E = 65537


def base64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def jwks_document() -> dict:
    return {
        "keys": [
            {
                "kty": "RSA",
                "kid": OIDC_KEY_ID,
                "use": "sig",
                "alg": "RS256",
                "n": base64url(RSA_N.to_bytes((RSA_N.bit_length() + 7) // 8, "big")),
                "e": base64url(RSA_E.to_bytes(3, "big")),
            }
        ]
    }


def oidc_claims(**overrides) -> dict:
    values = {
        "iss": OIDC_ISSUER,
        "aud": OIDC_AUDIENCE,
        "sub": "user-1",
        "tenant": "local",
        "exp": int(time.time()) + 60,
    }
    values.update(overrides)
    return values


def sign_jwt(claims: dict, kid: str = OIDC_KEY_ID) -> str:
    header = base64url(json.dumps({"alg": "RS256", "typ": "JWT", "kid": kid}).encode())
    payload = base64url(json.dumps(claims).encode())
    signing_input = f"{header}.{payload}".encode("ascii")
    digest = hashlib.sha256(signing_input).digest()
    encoded = bytes.fromhex("3031300d060960864801650304020105000420") + digest
    size = (RSA_N.bit_length() + 7) // 8
    message = b"\x00\x01" + b"\xff" * (size - len(encoded) - 3) + b"\x00" + encoded
    signature = pow(int.from_bytes(message, "big"), RSA_D, RSA_N)
    return f"{header}.{payload}.{base64url(signature.to_bytes(size, 'big'))}"


class FakeModel:
    async def generate(self, request):
        return Response(message=Message(role="assistant", content="hello from the service"))


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.secret = "test-secret"
        self.allowed = {"local"}
        self.principals = PrincipalStore()
        self.checkpoints = FileCheckpointStore(self.directory.name)
        self.server = None
        self.thread = None
        self.start_service()

    def start_service(self, remote_policy=None, authenticator=None):
        agent = create_agent(
            FakeModel(),
            self.allowed,
            self.principals,
            remote_policy,
        )
        server = ThreadingHTTPServer(
            ("127.0.0.1", 0),
            make_handler(
                agent,
                self.secret,
                self.allowed,
                self.principals,
                self.checkpoints,
                authenticator=authenticator,
            ),
        )
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.server = server
        self.thread = thread
        self.base = f"http://127.0.0.1:{server.server_port}"

    def stop_service(self):
        if self.server is None:
            return
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.server = None
        self.thread = None

    def restart_service(self, remote_policy=None, authenticator=None):
        self.stop_service()
        self.start_service(remote_policy, authenticator)

    def tearDown(self):
        self.stop_service()
        self.directory.cleanup()

    def start_pdp(self, allowed):
        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length", "0"))
                self.rfile.read(length)
                encoded = json.dumps(
                    {"allowed": allowed, "reason": "test policy"}
                ).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(encoded)))
                self.end_headers()
                self.wfile.write(encoded)

            def log_message(self, format, *args):
                return

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        def cleanup():
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

        self.addCleanup(cleanup)
        return f"http://127.0.0.1:{server.server_port}/authorize"

    def unavailable_url(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), BaseHTTPRequestHandler)
        url = f"http://127.0.0.1:{server.server_port}/authorize"
        server.server_close()
        return url

    def start_provider(self, issuer=OIDC_ISSUER):
        class Handler(BaseHTTPRequestHandler):
            base_url = ""

            def do_GET(self):
                if self.path == "/.well-known/openid-configuration":
                    body = {
                        "issuer": issuer,
                        "jwks_uri": self.base_url + "/jwks",
                    }
                elif self.path == "/jwks":
                    body = jwks_document()
                else:
                    self.send_response(404)
                    self.end_headers()
                    return
                encoded = json.dumps(body).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(encoded)))
                self.end_headers()
                self.wfile.write(encoded)

            def log_message(self, format, *args):
                return

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        Handler.base_url = f"http://127.0.0.1:{server.server_port}"
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        def cleanup():
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

        self.addCleanup(cleanup)
        return Handler.base_url + "/.well-known/openid-configuration"

    def oidc_verifier(self, discovery_url):
        return OidcVerifier(
            OIDC_ISSUER,
            OIDC_AUDIENCE,
            discovery_url=discovery_url,
            timeout=1,
        )

    def token(self, subject="user-1", tenant="local", ttl=60):
        return sign_token(self.secret, subject, tenant, time.time() + ttl)

    def post(self, token=None, body=None):
        headers = {"Content-Type": "application/json"}
        if token is not None:
            headers["Authorization"] = f"Bearer {token}"
        request = urllib.request.Request(
            self.base + "/run",
            data=json.dumps(body or {"prompt": "hi"}).encode(),
            headers=headers,
            method="POST",
        )
        return urllib.request.urlopen(request, timeout=5)

    def assert_status(self, expected, token=None, body=None):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self.post(token=token, body=body)
        self.assertEqual(caught.exception.code, expected)
        caught.exception.close()

    def test_healthz(self):
        with urllib.request.urlopen(self.base + "/healthz", timeout=5) as response:
            self.assertEqual(json.loads(response.read()), {"status": "ok"})

    def test_missing_token_is_rejected(self):
        self.assert_status(401)

    def test_invalid_signature_is_rejected(self):
        token = self.token()
        replacement = "0" if token[-1] != "0" else "1"
        self.assert_status(401, token=token[:-1] + replacement)

    def test_expired_token_is_rejected(self):
        self.assert_status(401, token=self.token(ttl=-1))

    def test_tenant_must_be_allowed(self):
        self.assert_status(403, token=self.token(tenant="other"))

    def test_valid_token_returns_output_and_saves_checkpoint(self):
        with self.post(token=self.token()) as response:
            body = json.loads(response.read())
        self.assertEqual(body["output"], "hello from the service")
        files = list(Path(self.directory.name).glob("*.json"))
        self.assertEqual(len(files), 1)
        saved = json.loads(files[0].read_text(encoding="utf-8"))
        self.assertEqual(saved["tenant_id"], "local")
        self.assertEqual(saved["session_id"], "local/user-1")
        self.assertEqual(saved["status"], "completed")

    def test_remote_policy_allows_the_run(self):
        self.restart_service(RemotePolicy(self.start_pdp(True), timeout=1))
        with self.post(token=self.token()) as response:
            body = json.loads(response.read())
        self.assertEqual(body["output"], "hello from the service")

    def test_remote_policy_denial_fails_closed(self):
        self.restart_service(RemotePolicy(self.start_pdp(False), timeout=1))
        self.assert_status(403, token=self.token())

    def test_remote_policy_unavailable_fails_closed(self):
        self.restart_service(RemotePolicy(self.unavailable_url(), timeout=0.2))
        self.assert_status(403, token=self.token())

    def test_policy_requires_a_bound_principal(self):
        decision = authorize(
            PrincipalStore(),
            self.allowed,
            Action(kind="model.generate", session_id="local/user-1"),
        )
        self.assertFalse(decision.allowed)

    def test_policy_rejects_expired_principal(self):
        store = PrincipalStore()
        store.bind(Principal("user-1", "local", int(time.time()) - 1))
        decision = authorize(
            store,
            self.allowed,
            Action(kind="model.generate", session_id="local/user-1"),
        )
        self.assertFalse(decision.allowed)

    def test_policy_rejects_tenant_outside_allowlist(self):
        store = PrincipalStore()
        store.bind(Principal("user-1", "other", int(time.time()) + 60))
        decision = authorize(
            store,
            self.allowed,
            Action(kind="model.generate", session_id="other/user-1"),
        )
        self.assertFalse(decision.allowed)

    def test_policy_allows_only_get_time(self):
        store = PrincipalStore()
        store.bind(Principal("user-1", "local", int(time.time()) + 60))
        session = "local/user-1"
        denied = authorize(
            store,
            self.allowed,
            Action(kind="tool.invoke", session_id=session, tool_name="delete_file"),
        )
        allowed = authorize(
            store,
            self.allowed,
            Action(kind="tool.invoke", session_id=session, tool_name="get_time"),
        )
        self.assertFalse(denied.allowed)
        self.assertTrue(allowed.allowed)

    def test_oidc_discovery_allows_token(self):
        discovery = self.start_provider()
        self.restart_service(
            authenticator=self.oidc_verifier(discovery).verify
        )
        with self.post(token=sign_jwt(oidc_claims())) as response:
            body = json.loads(response.read())
        self.assertEqual(body["output"], "hello from the service")

    def test_oidc_rejects_wrong_audience(self):
        discovery = self.start_provider()
        self.restart_service(
            authenticator=self.oidc_verifier(discovery).verify
        )
        self.assert_status(
            401,
            token=sign_jwt(oidc_claims(aud="other-service")),
        )

    def test_oidc_rejects_expired_token(self):
        discovery = self.start_provider()
        self.restart_service(
            authenticator=self.oidc_verifier(discovery).verify
        )
        self.assert_status(
            401,
            token=sign_jwt(oidc_claims(exp=int(time.time()) - 1)),
        )

    def test_oidc_rejects_unknown_key(self):
        discovery = self.start_provider()
        self.restart_service(
            authenticator=self.oidc_verifier(discovery).verify
        )
        self.assert_status(
            401,
            token=sign_jwt(oidc_claims(), kid="other-key"),
        )

    def test_oidc_provider_unavailable_fails_closed(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), BaseHTTPRequestHandler)
        discovery = (
            f"http://127.0.0.1:{server.server_port}"
            "/.well-known/openid-configuration"
        )
        server.server_close()
        self.restart_service(
            authenticator=OidcVerifier(
                OIDC_ISSUER,
                OIDC_AUDIENCE,
                discovery_url=discovery,
                timeout=0.2,
            ).verify
        )
        self.assert_status(401, token=sign_jwt(oidc_claims()))


if __name__ == "__main__":
    unittest.main()
