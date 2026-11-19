from __future__ import annotations

import json
import os
import sys
import time


def respond(frame: dict) -> None:
    sys.stdout.write(json.dumps(frame, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def main() -> int:
    token = os.environ.get("PRAXOVELA_PLUGIN_TOKEN", "")
    for raw in sys.stdin.buffer:
        try:
            request = json.loads(raw)
        except ValueError:
            continue
        if request.get("token") != token:
            respond(
                {
                    "id": request.get("id", ""),
                    "version": 1,
                    "ok": False,
                    "code": "INVALID_REQUEST",
                    "message": "token mismatch",
                }
            )
            continue
        method = request.get("method", "")
        payload = request.get("payload", "")
        if method == "health":
            respond(
                {
                    "id": request.get("id", ""),
                    "version": 1,
                    "ok": True,
                    "payload": "",
                }
            )
        elif method == "echo":
            respond(
                {
                    "id": request.get("id", ""),
                    "version": 1,
                    "ok": True,
                    "payload": payload,
                }
            )
        elif method == "denied":
            respond(
                {
                    "id": request.get("id", ""),
                    "version": 1,
                    "ok": False,
                    "code": "CAPABILITY_DENIED",
                    "message": "denied",
                }
            )
        elif method == "block":
            time.sleep(30)
        elif method == "shutdown":
            respond(
                {
                    "id": request.get("id", ""),
                    "version": 1,
                    "ok": True,
                    "payload": "",
                }
            )
            return 0
        elif method == "cancel":
            respond(
                {
                    "id": request.get("id", ""),
                    "version": 1,
                    "ok": True,
                    "payload": "",
                }
            )
        else:
            respond(
                {
                    "id": request.get("id", ""),
                    "version": 1,
                    "ok": False,
                    "code": "NOT_FOUND",
                    "message": "unknown method",
                }
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
