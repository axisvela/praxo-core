const http = require("node:http");

const {
  Agent,
  FuncHook,
  FuncTool,
  OpenAICompatibleModel,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
} = require("@axisvela/praxo-core");

const {
  AuthError,
  Principal,
  PrincipalStore,
  signToken,
  verifyBearer,
} = require("./auth");
const { FileCheckpointStore } = require("./checkpoint_store");
const { OidcVerifier } = require("./oidc");
const { RemotePolicy } = require("./remote_policy");


function createAuthenticator() {
  const issuer = process.env.PRAXO_OIDC_ISSUER || "";
  if (issuer) {
    const audience = process.env.PRAXO_OIDC_AUDIENCE || "";
    const jwksUrl = process.env.PRAXO_OIDC_JWKS_URL || "";
    if (!audience || !jwksUrl) {
      throw new Error(
        "PRAXO_OIDC_AUDIENCE and PRAXO_OIDC_JWKS_URL are required"
      );
    }
    return new OidcVerifier({
      issuer,
      audience,
      jwksUrl,
      tenantClaim: envOr("PRAXO_OIDC_TENANT_CLAIM", "tenant"),
      timeoutMs:
        Number(envOr("PRAXO_OIDC_TIMEOUT", "2")) * 1000,
    });
  }
  const secret = process.env.PRAXO_SERVICE_SECRET || "";
  if (!secret) {
    throw new Error(
      "PRAXO_SERVICE_SECRET or PRAXO_OIDC_ISSUER is required"
    );
  }
  return {
    verify: (header) => verifyBearer(header, secret),
  };
}

function envOr(name, fallback) {
  return process.env[name] || fallback;
}

function parseTenants(value) {
  return new Set(
    String(value)
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean)
  );
}


async function authorize(store, allowedTenants, action, remotePolicy = null) {
  const principal = store.lookup(action.sessionId);
  if (!principal) {
    return { allowed: false, reason: "trusted principal is missing" };
  }
  if (principal.expires <= Math.floor(Date.now() / 1000)) {
    return { allowed: false, reason: "trusted principal is expired" };
  }
  if (!allowedTenants.has(principal.tenant)) {
    return { allowed: false, reason: "tenant is not allowed" };
  }
  if (remotePolicy) {
    const remote = await remotePolicy.decide(principal, action);
    if (!remote.allowed) return remote;
  }
  if (action.kind === "model.generate") {
    return { allowed: true, reason: "principal may run the agent" };
  }
  if (action.kind !== "tool.invoke") {
    return { allowed: false, reason: "unsupported action" };
  }
  if (action.toolName !== "get_time") {
    return { allowed: false, reason: "only get_time is permitted" };
  }
  return { allowed: true, reason: "verified principal" };
}

function createAgent(model, allowedTenants, store, remotePolicy = null) {
  const selected =
    model ||
    new OpenAICompatibleModel({
      baseUrl: envOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
      apiKey: process.env.PRAXO_API_KEY || "",
      model: envOr("PRAXO_MODEL", "llama3.2"),
    });
  const principals = store || new PrincipalStore();
  const allowed =
    allowedTenants ||
    parseTenants(envOr("PRAXO_ALLOWED_TENANTS", "local"));
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
    policy: new FuncHook((action) =>
      authorize(principals, allowed, action, remotePolicy)
    ),
    requirePolicy: true,
    requireToolScope: true,
  });
}

async function runPrompt(agent, principal, prompt, checkpointStore = null) {
  const result = await agent.run(
    {
      id: principal.sessionId,
      tenantId: principal.tenant,
      workspaceId: "service",
    },
    prompt
  );
  if (checkpointStore) {
    checkpointStore.save({
      id: result.runId,
      sessionId: principal.sessionId,
      runId: result.runId,
      status: "completed",
      tenantId: principal.tenant,
      workspaceId: "service",
      messages: [{ role: ROLE_ASSISTANT, content: result.output }],
      createdAt: new Date().toISOString(),
    });
  }
  return result.output;
}

async function handleRequest(
  agent,
  authenticator,
  allowedTenants,
  store,
  method,
  pathname,
  authorization,
  body,
  checkpointStore = null
) {
  if (method === "GET" && pathname === "/healthz") {
    return { status: 200, body: { status: "ok" } };
  }
  if (method !== "POST" || pathname !== "/run") {
    return { status: 404, body: { error: "not found" } };
  }
  let principal;
  try {
    principal = await authenticator.verify(authorization || "");
  } catch (error) {
    return { status: 401, body: { error: error.message } };
  }
  if (!allowedTenants.has(principal.tenant)) {
    return { status: 403, body: { error: "tenant is not allowed" } };
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
  store.bind(principal);
  try {
    const output = await runPrompt(
      agent,
      principal,
      prompt,
      checkpointStore
    );
    return { status: 200, body: { output } };
  } catch (error) {
    if (error instanceof PolicyDeniedError) {
      return { status: 403, body: { error: error.message } };
    }
    return { status: 500, body: { error: "agent run failed" } };
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

function createHandler(
  agent,
  authenticator,
  allowedTenants,
  store,
  checkpointStore = null
) {
  return async (request, response) => {
    try {
      const url = new URL(request.url || "/", "http://localhost");
      const body = request.method === "POST" ? await readBody(request) : "";
      const result = await handleRequest(
        agent,
        authenticator,
        allowedTenants,
        store,
        request.method || "",
        url.pathname,
        request.headers.authorization,
        body,
        checkpointStore
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
  const authenticator = createAuthenticator();
  const allowed = parseTenants(
    envOr("PRAXO_ALLOWED_TENANTS", "local")
  );
  const policyUrl = process.env.PRAXO_POLICY_URL || "";
  const remotePolicy = policyUrl
    ? new RemotePolicy(
        policyUrl,
        Number(envOr("PRAXO_POLICY_TIMEOUT", "2")) * 1000
      )
    : null;
  const principals = new PrincipalStore();
  const checkpoints = new FileCheckpointStore(
    envOr("PRAXO_CHECKPOINT_DIR", "checkpoints")
  );
  const server = http.createServer(
    createHandler(
      createAgent(null, allowed, principals, remotePolicy),
      authenticator,
      allowed,
      principals,
      checkpoints
    )
  );
  server.listen(port, host, () => {
    console.log(`listening on http://${host}:${port}`);
  });
  return server;
}

function main() {
  const args = process.argv.slice(2);
  const secret = process.env.PRAXO_SERVICE_SECRET || "";
  const printIndex = args.indexOf("--print-token");
  if (printIndex >= 0) {
    if (!secret) {
      console.error("PRAXO_SERVICE_SECRET is required");
      process.exit(1);
    }
    const subject = args[printIndex + 1];
    const tenant = args[printIndex + 2];
    if (!subject || !tenant) {
      console.error("usage: --print-token SUBJECT TENANT [--ttl SECONDS]");
      process.exit(1);
    }
    const ttlIndex = args.indexOf("--ttl");
    const ttl = ttlIndex >= 0 ? Number(args[ttlIndex + 1]) : 3600;
    console.log(
      signToken(
        secret,
        subject,
        tenant,
        Math.floor(Date.now() / 1000) + ttl
      )
    );
    return;
  }
  const addrIndex = args.indexOf("--addr");
  const addr = addrIndex >= 0 ? args[addrIndex + 1] : "127.0.0.1:8080";
  const split = addr.lastIndexOf(":");
  const host = split > 0 ? addr.slice(0, split) : "127.0.0.1";
  const port = Number(split >= 0 ? addr.slice(split + 1) : addr);
  serve(host, port);
}

if (require.main === module) {
  main();
}

module.exports = {
  AuthError,
  FakeModel: class FakeModel {
    async generate() {
      return {
        message: {
          role: ROLE_ASSISTANT,
          content: "hello from the service",
        },
      };
    }
  },
  FileCheckpointStore,
  OidcVerifier,
  Principal,
  PrincipalStore,
  RemotePolicy,
  authorize,
  createAuthenticator,
  createAgent,
  createHandler,
  handleRequest,
  parseTenants,
  runPrompt,
  serve,
  signToken,
  verifyBearer,
};
