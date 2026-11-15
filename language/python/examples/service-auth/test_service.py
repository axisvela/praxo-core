import json
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

from praxo.model import Message, Response
from praxo.policy import Action

from service import (
    FileCheckpointStore,
    Principal,
    PrincipalStore,
    authorize,
    create_agent,
    make_handler,
    sign_token,
)


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
        agent = create_agent(FakeModel(), self.allowed, self.principals)
        self.server = ThreadingHTTPServer(
            ("127.0.0.1", 0),
            make_handler(
                agent,
                self.secret,
                self.allowed,
                self.principals,
                self.checkpoints,
            ),
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.directory.cleanup()

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


if __name__ == "__main__":
    unittest.main()
