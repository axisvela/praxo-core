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

module.exports = { RemotePolicy };
