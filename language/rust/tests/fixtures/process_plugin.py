import json
import os
import sys
import time

TOKEN = os.environ.get("PRAXOVELA_PLUGIN_TOKEN", "")


def respond(frame):
    sys.stdout.write(json.dumps(frame, separators=(",", ":")) + "\n")
    sys.stdout.flush()


for raw in sys.stdin.buffer:
    try:
        request = json.loads(raw)
    except ValueError:
        continue
    if request.get("token") != TOKEN:
        respond({
            "id": request.get("id", ""),
            "version": 1,
            "ok": False,
            "code": "INVALID_REQUEST",
            "message": "token mismatch",
        })
        continue
    method = request.get("method", "")
    if method in ("health", "cancel"):
        respond({"id": request.get("id", ""), "version": 1, "ok": True, "payload": ""})
    elif method == "echo":
        respond({
            "id": request.get("id", ""),
            "version": 1,
            "ok": True,
            "payload": request.get("payload", ""),
        })
    elif method == "denied":
        respond({
            "id": request.get("id", ""),
            "version": 1,
            "ok": False,
            "code": "CAPABILITY_DENIED",
            "message": "denied",
        })
    elif method == "block":
        time.sleep(30)
    elif method == "shutdown":
        respond({"id": request.get("id", ""), "version": 1, "ok": True, "payload": ""})
        raise SystemExit(0)
    else:
        respond({
            "id": request.get("id", ""),
            "version": 1,
            "ok": False,
            "code": "NOT_FOUND",
            "message": "unknown method",
        })
