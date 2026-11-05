# Bind Verified Identity and Policy

This recipe shows an application-level pattern for using a verified principal in
Core authorization. Core provides the authorization hook and final-operation
recheck; the application must authenticate the caller, bind the tenant and
resource, and fail closed.

It is not an identity provider, policy decision service, durable approval store,
or an exactly-once effect mechanism.

## Pattern

1. **Authenticate outside Core.** Verify the caller with your identity system
   and produce a principal containing actor ID, tenant, role, and expiry.
2. **Put only verified data in the context.** Never read the actor ID or role
   from model output or tool arguments.
3. **Authorize in the hook.** Reject a missing, expired, or malformed principal;
   check role, tenant, resource, tool name, and arguments.
4. **Recheck the final operation.** Middleware or approval edits can change the
   tool name or arguments; Core authorizes the final values again.
5. **Fail closed.** If required identity or policy infrastructure is unavailable,
   return an error; do not permit execution.

## Tested Example

The runnable example is the separate L4 recipe module
[`examples/recipes/identity-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/identity-go).
From that directory:

```sh
GOWORK=off go test -mod=readonly -run Identity -v ./...
```

| Check | Expected outcome |
| --- | --- |
| Missing verified principal | denied; zero tool effects |
| Expired principal | denied; zero tool effects |
| Tenant mismatch | denied; zero tool effects |
| Model claims an admin role | ignored; denied; zero tool effects |
| Verified operator for the matching tenant | allowed once |

The recipe stores the principal in a context value after authentication. In a
real service, that value must come from your verified request context or identity
middleware, not from the prompt or model.

## Important Limits

- A role string in tool arguments is untrusted input. The hook must use the
  verified principal.
- Identity authorization does not replace sandboxing, least-privilege
  credentials, network controls, or real-time safety.
- An approval decision is not a durable approval store; define binding, expiry,
  revocation, and audit in the application.
- A successful tool call is not proof of a committed external effect. Use an
  effect ledger or reconciliation for high-impact operations.

See the [security model](../security/index.md), [governed execution design](../reference/governed-execution.md),
and [adoption guide](../getting-started/adoption.md).
