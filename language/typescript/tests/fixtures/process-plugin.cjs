const readline = require("node:readline");

const token = process.env.PRAXOVELA_PLUGIN_TOKEN || "";
const rl = readline.createInterface({ input: process.stdin });

function respond(frame) {
  process.stdout.write(`${JSON.stringify(frame)}\n`);
}

rl.on("line", (line) => {
  let request;
  try {
    request = JSON.parse(line);
  } catch {
    return;
  }
  if (request.token !== token) {
    respond({
      id: request.id,
      version: 1,
      ok: false,
      code: "INVALID_REQUEST",
      message: "token mismatch",
    });
    return;
  }
  switch (request.method) {
    case "health":
    case "cancel":
      respond({ id: request.id, version: 1, ok: true, payload: "" });
      break;
    case "echo":
      respond({
        id: request.id,
        version: 1,
        ok: true,
        payload: request.payload,
      });
      break;
    case "denied":
      respond({
        id: request.id,
        version: 1,
        ok: false,
        code: "CAPABILITY_DENIED",
        message: "denied",
      });
      break;
    case "block":
      setTimeout(() => {}, 30_000);
      break;
    case "shutdown":
      respond({ id: request.id, version: 1, ok: true, payload: "" });
      process.exit(0);
      break;
    default:
      respond({
        id: request.id,
        version: 1,
        ok: false,
        code: "NOT_FOUND",
        message: "unknown method",
      });
  }
});
