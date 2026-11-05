# Verified Identity and Policy Recipe (Go)

This module shows an application-level pattern for binding a verified principal
to Core policy authorization. The application authenticates the caller and puts
the principal in a trusted context; Core only invokes the policy hook.

**Evidence level: L4 application recipe.** It is not an identity provider,
policy decision service, durable approval store, or Core capability. See the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -run Identity -v ./...
```

The tests cover missing, expired, tenant-mismatched, model-claimed admin, and
valid operator cases. See the
[identity and policy guide](../../../docs/guides/identity-policy.md).

From the repository root, `python scripts/test_go_identity.py -v` repeats the
flow in a fresh temporary application using the published package.
