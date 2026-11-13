import json
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

from praxo.model import Message, Response

from service import create_agent, make_handler


class FakeModel:
    async def generate(self, request):
        return Response(message=Message(role="assistant", content="hello from the service"))


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(create_agent(FakeModel())))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def test_requires_principal(self):
        request = urllib.request.Request(
            self.base + "/run",
            data=json.dumps({"prompt": "hi"}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with self.assertRaises(urllib.error.HTTPError) as caught:
            urllib.request.urlopen(request, timeout=5)
        self.assertEqual(caught.exception.code, 401)
        caught.exception.close()

    def test_returns_output(self):
        request = urllib.request.Request(
            self.base + "/run",
            data=json.dumps({"prompt": "hi"}).encode(),
            headers={
                "Content-Type": "application/json",
                "X-Praxo-Principal": "user-1",
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            body = json.loads(response.read())
        self.assertEqual(body["output"], "hello from the service")


if __name__ == "__main__":
    unittest.main()
