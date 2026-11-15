const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  FakeModel,
  FileCheckpointStore,
  OidcVerifier,
  PrincipalStore,
  RemotePolicy,
  createAgent,
  createHandler,
  signToken,
  verifyBearer,
} = require("./service");

const SECRET = "test-secret";
const ALLOWED = new Set(["local"]);
const OIDC_ISSUER = "https://issuer.example.com";
const OIDC_AUDIENCE = "praxo-service";
const OIDC_KID = "test-key";
const { privateKey, publicKey } = crypto.generateKeyPairSync("rsa", {
  modulusLength: 2048,
});

function hmacAuthenticator() {
  return {
    verify: (header) => verifyBearer(header, SECRET),
  };
}

function jwks() {
  const key = publicKey.export({ format: "jwk" });
  return {
    keys: [{ ...key, kid: OIDC_KID, use: "sig", alg: "RS256" }],
  };
}

function signJwt(claims, kid = OIDC_KID) {
  const header = Buffer.from(
    JSON.stringify({ alg: "RS256", typ: "JWT", kid })
  ).toString("base64url");
  const payload = Buffer.from(JSON.stringify(claims)).toString("base64url");
  const signature = crypto
    .sign("sha256", Buffer.from(`${header}.${payload}`), privateKey)
    .toString("base64url");
  return `${header}.${payload}.${signature}`;
}

function oidcClaims(overrides = {}) {
  return {
    iss: OIDC_ISSUER,
    aud: OIDC_AUDIENCE,
    sub: "user-1",
    tenant: "local",
    exp: Math.floor(Date.now() / 1000) + 60,
    ...overrides,
  };
}

async function withJwks(run) {
  const server = http.createServer((request, response) => {
    const encoded = JSON.stringify(jwks());
    response.writeHead(200, {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(encoded),
    });
    response.end(encoded);
  });
  const url = `${await listen(server)}/.well-known/jwks.json`;
  try {
    await run(url);
  } finally {
    await close(server);
  }
}

function oidcVerifier(jwksUrl) {
  return new OidcVerifier({
    issuer: OIDC_ISSUER,
    audience: OIDC_AUDIENCE,
    jwksUrl,
    timeoutMs: 1000,
  });
}

async function listen(server) {
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

async function close(server) {
  await new Promise((resolve) => server.close(resolve));
}

async function withService(
  run,
  remotePolicy = null,
  authenticator = hmacAuthenticator()
) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "praxo-service-"));
  const principals = new PrincipalStore();
  const checkpoints = new FileCheckpointStore(directory);
  const server = http.createServer(
    createHandler(
      createAgent(new FakeModel(), ALLOWED, principals, remotePolicy),
      authenticator,
      ALLOWED,
      principals,
      checkpoints
    )
  );
  const base = await listen(server);
  try {
    await run({ base, directory, principals, checkpoints });
  } finally {
    await close(server);
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

async function withPdp(allowed, run) {
  const server = http.createServer((request, response) => {
    request.resume();
    request.on("end", () => {
      const encoded = JSON.stringify({
        allowed,
        reason: "test policy",
      });
      response.writeHead(200, {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(encoded),
      });
      response.end(encoded);
    });
  });
  const url = `${await listen(server)}/authorize`;
  try {
    await run(url);
  } finally {
    await close(server);
  }
}

async function unavailableUrl() {
  const server = http.createServer(() => {});
  const base = await listen(server);
  await close(server);
  return `${base}/authorize`;
}

function token(subject = "user-1", tenant = "local", ttl = 60) {
  return signToken(
    SECRET,
    subject,
    tenant,
    Math.floor(Date.now() / 1000) + ttl
  );
}

async function post(base, value, body = { prompt: "hi" }) {
  const headers = { "Content-Type": "application/json" };
  if (value) headers.Authorization = `Bearer ${value}`;
  return fetch(`${base}/run`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

test("health check does not require a token", async () => {
  await withService(async ({ base }) => {
    const response = await fetch(`${base}/healthz`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: "ok" });
  });
});

test("missing token is rejected", async () => {
  await withService(async ({ base }) => {
    const response = await post(base, null);
    assert.equal(response.status, 401);
  });
});

test("invalid signature is rejected", async () => {
  await withService(async ({ base }) => {
    const value = token();
    const replacement = value.endsWith("0") ? "1" : "0";
    const response = await post(base, value.slice(0, -1) + replacement);
    assert.equal(response.status, 401);
  });
});

test("expired token is rejected", async () => {
  await withService(async ({ base }) => {
    const response = await post(base, token("user-1", "local", -1));
    assert.equal(response.status, 401);
  });
});

test("tenant must be allowed", async () => {
  await withService(async ({ base }) => {
    const response = await post(base, token("user-1", "other"));
    assert.equal(response.status, 403);
  });
});

test("valid token returns output and saves a checkpoint", async () => {
  await withService(async ({ base, directory }) => {
    const response = await post(base, token());
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      output: "hello from the service",
    });
    const files = fs
      .readdirSync(directory)
      .filter((name) => name.endsWith(".json"));
    assert.equal(files.length, 1);
    const saved = JSON.parse(
      fs.readFileSync(path.join(directory, files[0]), "utf8")
    );
    assert.equal(saved.tenantId, "local");
    assert.equal(saved.sessionId, "local/user-1");
    assert.equal(saved.status, "completed");
  });
});

test("OIDC token returns output and saves a checkpoint", async () => {
  await withJwks(async (url) => {
    await withService(async ({ base, directory }) => {
      const response = await post(base, signJwt(oidcClaims()));
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), {
        output: "hello from the service",
      });
      const files = fs
        .readdirSync(directory)
        .filter((name) => name.endsWith(".json"));
      assert.equal(files.length, 1);
      const saved = JSON.parse(
        fs.readFileSync(path.join(directory, files[0]), "utf8")
      );
      assert.equal(saved.tenantId, "local");
      assert.equal(saved.sessionId, "local/user-1");
    }, null, oidcVerifier(url));
  });
});

test("OIDC expired token is rejected", async () => {
  await withJwks(async (url) => {
    await withService(async ({ base }) => {
      const response = await post(
        base,
        signJwt(
          oidcClaims({
            exp: Math.floor(Date.now() / 1000) - 1,
          })
        )
      );
      assert.equal(response.status, 401);
    }, null, oidcVerifier(url));
  });
});

test("OIDC audience must match", async () => {
  await withJwks(async (url) => {
    await withService(async ({ base }) => {
      const response = await post(
        base,
        signJwt(oidcClaims({ aud: "other-service" }))
      );
      assert.equal(response.status, 401);
    }, null, oidcVerifier(url));
  });
});

test("OIDC token requires a tenant claim", async () => {
  await withJwks(async (url) => {
    await withService(async ({ base }) => {
      const claims = oidcClaims();
      delete claims.tenant;
      const response = await post(base, signJwt(claims));
      assert.equal(response.status, 401);
    }, null, oidcVerifier(url));
  });
});

test("OIDC invalid signature is rejected", async () => {
  await withJwks(async (url) => {
    await withService(async ({ base }) => {
      const parts = signJwt(oidcClaims()).split(".");
      const payload = JSON.parse(
        Buffer.from(parts[1], "base64url").toString("utf8")
      );
      payload.sub = "attacker";
      const tampered = `${parts[0]}.${Buffer.from(
        JSON.stringify(payload)
      ).toString("base64url")}.${parts[2]}`;
      const response = await post(base, tampered);
      assert.equal(response.status, 401);
    }, null, oidcVerifier(url));
  });
});

test("OIDC unknown key id is rejected", async () => {
  await withJwks(async (url) => {
    await withService(async ({ base }) => {
      const response = await post(
        base,
        signJwt(oidcClaims(), "unknown-key")
      );
      assert.equal(response.status, 401);
    }, null, oidcVerifier(url));
  });
});

test("OIDC JWKS unavailable fails closed", async () => {
  const url = await unavailableUrl();
  await withService(async ({ base }) => {
    const response = await post(base, signJwt(oidcClaims()));
    assert.equal(response.status, 401);
  }, null, oidcVerifier(url));
});

test("remote policy allow permits the run", async () => {
  await withPdp(true, async (url) => {
    await withService(async ({ base }) => {
      const response = await post(base, token());
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), {
        output: "hello from the service",
      });
    }, new RemotePolicy(url, 1000));
  });
});

test("remote policy denial fails closed", async () => {
  await withPdp(false, async (url) => {
    await withService(async ({ base }) => {
      const response = await post(base, token());
      assert.equal(response.status, 403);
    }, new RemotePolicy(url, 1000));
  });
});

test("remote policy unavailable fails closed", async () => {
  const url = await unavailableUrl();
  await withService(async ({ base }) => {
    const response = await post(base, token());
    assert.equal(response.status, 403);
  }, new RemotePolicy(url, 200));
});
