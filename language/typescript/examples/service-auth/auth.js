const crypto = require("node:crypto");

const { AuthError } = require("./oidc");

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

module.exports = {
  AuthError,
  Principal,
  PrincipalStore,
  signToken,
  verifyBearer,
};
