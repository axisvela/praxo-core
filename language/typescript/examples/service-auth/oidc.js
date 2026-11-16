const crypto = require("node:crypto");

const { ProviderDiscovery } = require("./discovery");
const { AuthError } = require("./errors");

const OIDC_ALGORITHMS = {
  RS256: "sha256",
  RS384: "sha384",
  RS512: "sha512",
};

function decodeJson(segment) {
  try {
    return JSON.parse(
      Buffer.from(segment, "base64url").toString("utf8")
    );
  } catch {
    throw new AuthError("invalid token");
  }
}

function audienceMatches(value, expected) {
  if (typeof value === "string") return value === expected;
  if (Array.isArray(value)) return value.includes(expected);
  return false;
}

class OidcVerifier {
  constructor({
    issuer,
    audience,
    jwksUrl = "",
    discovery = null,
    discoveryUrl = "",
    tenantClaim = "tenant",
    timeoutMs = 2000,
    clockSkewSeconds = 0,
  }) {
    this.issuer = issuer;
    this.audience = audience;
    this.jwksUrl = jwksUrl;
    this.discovery =
      discovery ||
      (issuer && !jwksUrl
        ? new ProviderDiscovery({ issuer, discoveryUrl, timeoutMs })
        : null);
    this.tenantClaim = tenantClaim;
    this.timeoutMs = timeoutMs;
    this.clockSkewSeconds = clockSkewSeconds;
    this.keys = null;
    this.fetchedAt = 0;
    this.cacheMs = 300000;
  }

  async resolveJwksUrl() {
    if (this.jwksUrl) {
      return this.jwksUrl;
    }
    if (this.discovery) {
      return this.discovery.jwksUri();
    }
    throw new AuthError("identity provider JWKS is not configured");
  }

  async verify(header) {
    if (!header.startsWith("Bearer ")) {
      throw new AuthError("missing bearer token");
    }
    const token = header.slice("Bearer ".length);
    const parts = token.split(".");
    if (parts.length !== 3) {
      throw new AuthError("invalid token");
    }
    const [encodedHeader, encodedPayload, encodedSignature] = parts;
    const tokenHeader = decodeJson(encodedHeader);
    const payload = decodeJson(encodedPayload);
    if (
      !tokenHeader ||
      typeof tokenHeader !== "object" ||
      Array.isArray(tokenHeader)
    ) {
      throw new AuthError("invalid token header");
    }
    const algorithm = tokenHeader.alg;
    const kid = tokenHeader.kid;
    if (
      typeof algorithm !== "string" ||
      !Object.hasOwn(OIDC_ALGORITHMS, algorithm)
    ) {
      throw new AuthError("unsupported token algorithm");
    }
    if (typeof kid !== "string" || !kid) {
      throw new AuthError("token is missing key id");
    }
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
      throw new AuthError("invalid token claims");
    }
    if (payload.iss !== this.issuer) {
      throw new AuthError("invalid token issuer");
    }
    if (!audienceMatches(payload.aud, this.audience)) {
      throw new AuthError("invalid token audience");
    }
    const now = Math.floor(Date.now() / 1000);
    if (
      !Number.isInteger(payload.exp) ||
      payload.exp <= now - this.clockSkewSeconds
    ) {
      throw new AuthError("token is expired");
    }
    if (
      payload.nbf !== undefined &&
      (!Number.isInteger(payload.nbf) ||
        payload.nbf > now + this.clockSkewSeconds)
    ) {
      throw new AuthError("token is not active");
    }
    const subject = payload.sub;
    const tenant = payload[this.tenantClaim];
    if (typeof subject !== "string" || !subject) {
      throw new AuthError("token is missing subject");
    }
    if (typeof tenant !== "string" || !tenant) {
      throw new AuthError("token is missing tenant");
    }
    let jwk = await this.findKey(kid, algorithm, false);
    if (!jwk) {
      jwk = await this.findKey(kid, algorithm, true);
    }
    if (!jwk) {
      throw new AuthError("unknown token key");
    }
    let valid = false;
    try {
      valid = crypto.verify(
        OIDC_ALGORITHMS[algorithm],
        Buffer.from(`${encodedHeader}.${encodedPayload}`),
        crypto.createPublicKey({ key: jwk, format: "jwk" }),
        Buffer.from(encodedSignature, "base64url")
      );
    } catch {
      valid = false;
    }
    if (!valid) {
      throw new AuthError("invalid token signature");
    }
    return {
      subject,
      tenant,
      expires: payload.exp,
      sessionId: `${tenant}/${subject}`,
    };
  }

  async findKey(kid, algorithm, refresh) {
    const now = Date.now();
    if (!this.keys || refresh || now - this.fetchedAt > this.cacheMs) {
      this.keys = await this.fetchKeys();
      this.fetchedAt = now;
    }
    return (
      this.keys.find(
        (key) =>
          key.kid === kid &&
          key.kty === "RSA" &&
          (!key.use || key.use === "sig") &&
          (!key.alg || key.alg === algorithm)
      ) || null
    );
  }

  async fetchKeys() {
    const jwksUrl = await this.resolveJwksUrl();
    try {
      const response = await fetch(jwksUrl, {
        signal: AbortSignal.timeout(Math.max(1, this.timeoutMs)),
      });
      if (response.status !== 200) {
        throw new Error("jwks status");
      }
      const body = await response.json();
      if (!body || !Array.isArray(body.keys)) {
        throw new Error("jwks body");
      }
      return body.keys;
    } catch (error) {
      if (error instanceof AuthError) {
        throw error;
      }
      throw new AuthError("identity provider unavailable");
    }
  }
}

module.exports = { AuthError, OidcVerifier };
