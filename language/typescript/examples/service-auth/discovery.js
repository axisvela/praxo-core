const { AuthError } = require("./errors");

function trimSlash(value) {
  return String(value).replace(/\/+$/, "");
}

async function fetchMetadata(url, timeoutMs) {
  try {
    const response = await fetch(url, {
      signal: AbortSignal.timeout(Math.max(1, timeoutMs)),
    });
    if (response.status !== 200) {
      throw new Error("metadata status");
    }
    return await response.json();
  } catch {
    throw new AuthError("identity provider unavailable");
  }
}

class ProviderDiscovery {
  constructor({
    issuer = "",
    discoveryUrl = "",
    timeoutMs = 2000,
    cacheMs = 300000,
  } = {}) {
    this.issuer = trimSlash(issuer);
    this.discoveryUrl = discoveryUrl;
    this.timeoutMs = timeoutMs;
    this.cacheMs = cacheMs;
    this.cached = null;
    this.fetchedAt = 0;
  }

  async metadata() {
    const now = Date.now();
    if (this.cached && now - this.fetchedAt <= this.cacheMs) {
      return this.cached;
    }
    const url =
      this.discoveryUrl ||
      `${this.issuer}/.well-known/openid-configuration`;
    if (!this.discoveryUrl && !this.issuer) {
      throw new AuthError("provider discovery is not configured");
    }
    const body = await fetchMetadata(url, this.timeoutMs);
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new AuthError("invalid provider metadata");
    }
    if (this.issuer && trimSlash(body.issuer) !== this.issuer) {
      throw new AuthError("invalid provider issuer");
    }
    this.cached = body;
    this.fetchedAt = now;
    return body;
  }

  async jwksUri() {
    const metadata = await this.metadata();
    if (typeof metadata.jwks_uri !== "string" || !metadata.jwks_uri) {
      throw new AuthError("provider metadata is missing jwks_uri");
    }
    return metadata.jwks_uri;
  }

  async introspectionEndpoint() {
    const metadata = await this.metadata();
    if (
      typeof metadata.introspection_endpoint !== "string" ||
      !metadata.introspection_endpoint
    ) {
      throw new AuthError(
        "provider metadata is missing introspection_endpoint"
      );
    }
    return metadata.introspection_endpoint;
  }

  async revocationEndpoint() {
    const metadata = await this.metadata();
    if (
      typeof metadata.revocation_endpoint !== "string" ||
      !metadata.revocation_endpoint
    ) {
      throw new AuthError("provider metadata is missing revocation_endpoint");
    }
    return metadata.revocation_endpoint;
  }
}

module.exports = { ProviderDiscovery };
