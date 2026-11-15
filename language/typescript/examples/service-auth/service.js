const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");

const {
  Agent,
  FuncHook,
  FuncTool,
  OpenAICompatibleModel,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
} = require("@axisvela/praxo-core");

class AuthError extends Error {}

class Principal {
  constructor(subject, tenant, expires) {
    this.subject = subject;
    this.tenant = tenant;
    this.expires = expires;
  }

  get sessionId() {
    return `${this.tenant}/${this.subject}`;
  }
}

class PrincipalStore {
  constructor() {
    this.principals = new Map();
  }

  bind(principal) {
    this.principals.set(principal.sessionId, principal);
  }

  lookup(sessionId) {
    return this.principals.get(sessionId);
  }
}

class RemotePolicy {
  constructor(url, timeoutMs = 2000) {
    this.url = url;
    this.timeoutMs = timeoutMs;
  }

  async decide(principal, action) {
    const payload = {
      principal: {
        subject: principal.subject,
        tenant: principal.tenant,
      },
      action: {
        kind: action.kind,
        tool_name: action.toolName || "",
        arguments: action.arguments || {},
      },
    };
    try {
      const response = await fetch(this.url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(Math.max(1, this.timeoutMs)),
      });
      if (response.status !== 200) {
        return { allowed: false, reason: "policy service returned an error" };
      }
      const decision = await response.json();
      if (
        !decision ||
        typeof decision !== "object" ||
        typeof decision.allowed !== "boolean"
      ) {
        return {
          allowed: false,
          reason: "policy service returned an invalid decision",
        };
      }
      return {
        allowed: decision.allowed,
        reason:
          typeof decision.reason === "string" ? decision.reason : "",
      };
    } catch {
      return { allowed: false, reason: "policy service unavailable" };
    }
  }
}

class FileCheckpointStore {
  constructor(directory) {
    this.directory = path.resolve(directory);
    fs.mkdirSync(this.directory, { recursive: true });
  }

  save(checkpoint) {
    const name =
      String(checkpoint.runId).replace(/[^A-Za-z0-9_.-]/g, "_") ||
      "checkpoint";
    const target = path.join(this.directory, `${name}.json`);
    const temporary = `${target}.tmp`;
    fs.writeFileSync(temporary, JSON.stringify(checkpoint), "utf8");
    fs.renameSync(temporary, target);
  }
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

function signToken(secret, subject, tenant, expires) {
  const payload = Buffer.from(
    JSON.stringify({
      sub: subject,
      tenant,
      exp: Math.floor(expires),
    })
  ).toString("base64url");
  const signature = crypto
    .createHmac("sha256", secret)
    .update(payload)
    .digest("hex");
  return `${payload}.${signature}`;
}

function verifyBearer(header, secret, now = Math.floor(Date.now() / 1000)) {
  if (!header.startsWith("Bearer ")) {
    throw new AuthError("missing bearer token");
  }
  const token = header.slice("Bearer ".length);
  const parts = token.split(".");
  if (parts.length !== 2) {
    throw new AuthError("invalid token");
  }
  const [payloadPart, signaturePart] = parts;
  const expected = crypto
    .createHmac("sha256", secret)
    .update(payloadPart)
    .digest();
  const provided = Buffer.from(signaturePart, "hex");
  if (
    provided.length !== expected.length ||
    !crypto.timingSafeEqual(provided, expected)
  ) {
    throw new AuthError("invalid token signature");
  }
  let payload;
  try {
    payload = JSON.parse(
      Buffer.from(payloadPart, "base64url").toString("utf8")
    );
  } catch {
    throw new AuthError("invalid token claims");
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new AuthError("invalid token claims");
  }
  const subject = payload.sub;
  const tenant = payload.tenant;
  const expires = payload.exp;
  if (typeof subject !== "string" || !subject) {
    throw new AuthError("token is missing subject");
  }
  if (typeof tenant !== "string" || !tenant) {
    throw new AuthError("token is missing tenant");
  }
  if (!Number.isInteger(expires)) {
    throw new AuthError("token is missing expiration");
  }
  if (expires <= now) {
    throw new AuthError("token is expired");
  }
  return new Principal(subject, tenant, expires);
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
  secret,
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
    principal = verifyBearer(authorization || "", secret);
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
  secret,
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
        secret,
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
  const secret = process.env.PRAXO_SERVICE_SECRET || "";
  if (!secret) {
    throw new Error("PRAXO_SERVICE_SECRET is required");
  }
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
      secret,
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
  Principal,
  PrincipalStore,
  RemotePolicy,
  authorize,
  createAgent,
  createHandler,
  handleRequest,
  parseTenants,
  runPrompt,
  serve,
  signToken,
  verifyBearer,
};
