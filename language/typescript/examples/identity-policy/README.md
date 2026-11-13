# Identity and Policy

This example uses published npm `@axisvela/praxo-core@0.5.0` to bind a trusted
principal to Core policy authorization. The application owns authentication and
principal storage; Core only calls the policy hook.

The session ID is used here as a lookup key into an application-owned principal
store. In production, derive the principal from verified request context, not
from a model or client claim. The model claims `role: admin` and a tenant; those
claims are ignored.

## Run the deterministic test

No endpoint is required:

```bash
npm install
npm test
```

The tests cover missing, inactive, role-mismatched, tenant-mismatched, and valid
operator cases. Denied calls never invoke the tool.

## Boundaries

- Core does not authenticate callers or issue credentials.
- Policy sees the action and session; the application binds the trusted
  principal.
- Denial returns `AGENT_POLICY_DENIED` before the effect runs.
- Do not trust model-supplied tenant, role, or identity claims.
