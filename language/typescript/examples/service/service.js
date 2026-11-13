const http = require("node:http");

const {
  Agent,
  FuncHook,
  FuncTool,
  OpenAICompatibleModel,
  Registry,
  ROLE_ASSISTANT,
} = require("@axisvela/praxo-core");

function envOr(name, fallback) {
  return process.env[name] || fallback;
}

function createAgent(model) {
  const selected =
    model ||
    new OpenAICompatibleModel({
      baseUrl: envOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
      apiKey: process.env.PRAXO_API_KEY || "",
      model: envOr("PRAXO_MODEL", "llama3.2"),
    });
  const tools = new Registry();
  tools.register(
    new FuncTool("get_time", "Return the current UTC time in ISO 8601 format.", () =>
      new Date().toISOString()
    )
  );
  return new Agent({
    model: selected,
    tools,
    systemPrompt: "You are a concise service assistant. Use tools when they help.",
    maxSteps: 4,
    allowedTools: ["get_time"],
    policy: new FuncHook((action) => {
      if (action.kind === "model.generate") return { allowed: true };
      if (action.kind === "tool.invoke") {
        return {
          allowed: action.toolName === "get_time",
          reason: "only get_time is permitted",
        };
      }
      return { allowed: false, reason: "unsupported action" };
    }),
  });
}

async function handleRequest(agent, tenant, method, path, principal, body) {
  if (method === "GET" && path === "/healthz") {
    return { status: 200, body: { status: "ok" } };
  }
  if (method !== "POST" || path !== "/run") {
    return { status: 404, body: { error: "not found" } };
  }
  if (!principal) {
    return { status: 401, body: { error: "missing X-Praxo-Principal" } };
  }
  let payload;
  try {
    payload = JSON.parse(body);
  } catch {
    return { status: 400, body: { error: "invalid JSON body" } };
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { status: 400, body: { error: "invalid JSON body" } };
  }
  const prompt = typeof payload.prompt === "string" ? payload.prompt : "";
  if (!prompt) {
    return { status: 400, body: { error: "prompt is required" } };
  }
  try {
    const result = await agent.run(
      { id: principal, tenantId: tenant, workspaceId: "service" },
      prompt
    );
    return { status: 200, body: { output: result.output } };
  } catch (error) {
    return { status: 500, body: { error: error.message } };
  }
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let data = "";
    request.on("data", (chunk) => {
      data += chunk;
      if (data.length > 65536) {
        reject(new Error("body too large"));
        request.destroy();
      }
    });
    request.on("end", () => resolve(data));
    request.on("error", reject);
  });
}

function createHandler(agent, tenant = envOr("PRAXO_TENANT", "local")) {
  return async (request, response) => {
    try {
      const url = new URL(request.url || "/", "http://localhost");
      const body = request.method === "POST" ? await readBody(request) : "";
      const result = await handleRequest(
        agent,
        tenant,
        request.method || "",
        url.pathname,
        request.headers["x-praxo-principal"],
        body
      );
      const encoded = JSON.stringify(result.body);
      response.writeHead(result.status, {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(encoded),
      });
      response.end(encoded);
    } catch {
      const encoded = JSON.stringify({ error: "invalid request" });
      response.writeHead(400, {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(encoded),
      });
      response.end(encoded);
    }
  };
}

function serve(host = "127.0.0.1", port = 8080) {
  const server = http.createServer(createHandler(createAgent()));
  server.listen(port, host, () => {
    console.log(`listening on http://${host}:${port}`);
  });
  return server;
}

if (require.main === module) {
  serve();
}

module.exports = {
  FakeModel: class FakeModel {
    async generate() {
      return { message: { role: ROLE_ASSISTANT, content: "hello from the service" } };
    }
  },
  createAgent,
  createHandler,
  handleRequest,
  serve,
};
