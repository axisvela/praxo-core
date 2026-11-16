const { ProviderDiscovery } = require("./discovery");
const { AuthError } = require("./errors");

function bearerToken(header) {
  if (!header.startsWith("Bearer ")) {
    throw new AuthError("missing bearer token");
  }
  const token = header.slice("Bearer ".length);
  if (!token) {
    throw new AuthError("missing bearer token");
  }
  return token;
}

function authHeaders(clientId, clientSecret) {
  if (!clientId) {
    return { "Content-Type": "application/x-www-form-urlencoded" };
  }
  return {
    "Content-Type": "application/x-www-form-urlencoded",
    Authorization: `Basic ${Buffer.from(
      `${clientId}:${clientSecret}`
    ).toString("base64")}`,
  };
}

async function postForm(url, form, headers, timeoutMs) {
  try {
    return await fetch(url, {
      method: "POST",
      headers,
      body: form.toString(),
      signal: AbortSignal.timeout(Math.max(1, timeoutMs)),
    });
  } catch {
    throw new AuthError("identity provider unavailable");
  }
}

class IntrospectionVerifier {
  constructor({
    url = "",
    issuer = "",
    discovery = null,
    discoveryUrl = "",
    clientId = "",
    clientSecret = "",
    tenantClaim = "tenant",
    timeoutMs = 2000,
  }) {
    this.url = url;
    this.clientId = clientId;
    this.clientSecret = clientSecret;
    this.tenantClaim = tenantClaim;
    this.timeoutMs = timeoutMs;
    this.discovery =
      discovery ||
      (issuer && !url
        ? new ProviderDiscovery({ issuer, discoveryUrl, timeoutMs })
        : null);
  }

  async endpoint() {
    if (this.url) {
      return this.url;
    }
    if (this.discovery) {
      return this.discovery.introspectionEndpoint();
    }
    throw new AuthError("introspection endpoint is not configured");
  }

  async verify(header) {
    const token = bearerToken(header);
    const endpoint = await this.endpoint();
    const form = new URLSearchParams({ token });
    if (!this.clientId) {
      form.set("client_id", this.clientId);
      form.set("client_secret", this.clientSecret);
    }
    const response = await postForm(
      endpoint,
      form,
      authHeaders(this.clientId, this.clientSecret),
      this.timeoutMs
    );
    if (response.status !== 200) {
      throw new AuthError("identity provider unavailable");
    }
    let body;
    try {
      body = await response.json();
    } catch {
      throw new AuthError("invalid introspection response");
    }
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new AuthError("invalid introspection response");
    }
    if (body.active !== true) {
      throw new AuthError("token is not active");
    }
    const subject = body.sub;
    const tenant = body[this.tenantClaim];
    const expires = body.exp;
    if (typeof subject !== "string" || !subject) {
      throw new AuthError("token is missing subject");
    }
    if (typeof tenant !== "string" || !tenant) {
      throw new AuthError("token is missing tenant");
    }
    if (!Number.isInteger(expires)) {
      throw new AuthError("token is missing expiration");
    }
    if (expires <= Math.floor(Date.now() / 1000)) {
      throw new AuthError("token is expired");
    }
    return {
      subject,
      tenant,
      expires,
      sessionId: `${tenant}/${subject}`,
    };
  }
}

async function revokeToken({
  token,
  url = "",
  issuer = "",
  discovery = null,
  discoveryUrl = "",
  clientId = "",
  clientSecret = "",
  timeoutMs = 2000,
  tokenTypeHint = "access_token",
}) {
  if (typeof token !== "string" || !token) {
    throw new AuthError("revocation token is required");
  }
  const endpoint =
    url ||
    (discovery
      ? await discovery.revocationEndpoint()
      : issuer
        ? await new ProviderDiscovery({
            issuer,
            discoveryUrl,
            timeoutMs,
          }).revocationEndpoint()
        : "");
  if (!endpoint) {
    throw new AuthError("revocation endpoint is not configured");
  }
  const form = new URLSearchParams({
    token,
    token_type_hint: tokenTypeHint,
  });
  if (!clientId) {
    form.set("client_id", clientId);
    form.set("client_secret", clientSecret);
  }
  const response = await postForm(
    endpoint,
    form,
    authHeaders(clientId, clientSecret),
    timeoutMs
  );
  if (response.status !== 200) {
    throw new AuthError("token revocation failed");
  }
  return true;
}

module.exports = { IntrospectionVerifier, revokeToken };
