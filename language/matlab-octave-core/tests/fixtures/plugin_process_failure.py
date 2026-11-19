import json
import os
import sys
import time


mode = sys.argv[1]
for line in sys.stdin:
    request = json.loads(line)
    if request.get("token") != os.environ["PRAXOVELA_PLUGIN_TOKEN"]:
        raise SystemExit(2)
    if mode == "exit":
        raise SystemExit(0)
    if mode == "stall":
        time.sleep(30)
        continue
    response = {"id": request["id"], "version": 1, "ok": True, "payload": ""}
    if request["method"] != "health":
        if mode == "exit-after-health":
            raise SystemExit(0)
        if mode == "wrong-id":
            response["id"] = "unrelated"
        elif mode == "wrong-version":
            response["version"] = 2
        elif mode == "bad-ok":
            response["ok"] = "true"
        elif mode == "bad-base64":
            response["payload"] = "!invalid!"
        elif mode == "partial":
            sys.stdout.write('{"id":')
            sys.stdout.flush()
            time.sleep(30)
            continue
        elif mode == "bad-json":
            sys.stdout.write("not json\n")
            sys.stdout.flush()
            continue
    print(json.dumps(response), flush=True)
