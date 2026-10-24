# Plugin Trust and SBOM Handoff

**Status:** public handoff checklist. This document explains what the product
must verify before starting a plugin host. It is not a signature verifier, an
SBOM store, or a security certification.

## Boundary

PRAXO-CORE hosts start already-verified payloads. The product owns fetching,
signature verification, SBOM policy, trust roots, materialization, and update
policy.

| Responsibility | PRAXO-CORE | Product |
| --- | --- | --- |
| Strict manifest parse and v1 validation | yes | must call it |
| Signed-profile presence check | yes | must enforce it |
| Cryptographic signature verification | no | yes |
| Trust roots, key rotation, revocation | no | yes |
| Artifact download and digest check | no | yes |
| SBOM fetch, match, and policy | no | yes |
| Content-addressed materialization | no | yes |
| Process/WASM runtime limits | yes | must require them |
| Container isolation | no | yes |
| Lifecycle and ACTIVE gate | yes | must use it |
| Durable evidence and audit | no | yes |

## Artifact Set

A signed plugin release should include:

1. **Manifest v1**: strict JSON with `schemaVersion`, `id`, `version`, `kind`,
   `entrypoint`, `protocol`, `capabilities`, `permissions`, `limits`,
   `isolation`, `health`, `signature`, and `sbom`.
2. **Detached signature**: the signature over the canonical descriptor bytes.
   The manifest carries only the algorithm and `keyId`, not the signature value.
3. **SBOM**: SPDX or CycloneDX describing the artifact and its dependencies.
4. **Artifact bytes**: process binary, WASM module, or container image.
5. **Provenance or attestation** where available: build identity, source
   revision, and signer.

The manifest `signature` field is an identity declaration. `ValidateTrust` only
checks that a signature identity and SBOM path are present; it does not verify
cryptographic validity.

## Required Product Flow

1. Fetch the descriptor and artifacts from a trusted source over TLS or a
   pinned channel.
2. Parse with `plugin.ParseManifest`. It rejects unknown fields and trailing
   data.
3. Enforce the trust profile with `ValidateTrust(plugin.TrustSigned)`. Unsigned
   artifacts are allowed only through an explicit local-development profile.
4. Verify the detached signature over the canonical descriptor bytes.
   - Allowlist acceptable algorithms.
   - Resolve `keyId` in the product trust store.
   - Check key status, rotation, and revocation.
   - Reject unknown or expired keys.
5. Verify the artifact digest against the signed descriptor and SBOM.
6. Verify the SBOM matches the artifact digest and satisfies product policy for
   licenses, vulnerabilities, and provenance.
7. Check compatibility: `schemaVersion`, contract `kind`, protocol, isolation,
   core version, and platform.
8. Bind permissions to the tenant and workspace. The manifest is deny-by-default;
   do not add ambient environment variables or broader filesystem/network grants.
9. Materialize the artifact at a content-addressed, read-only path. Reject
   symlinks, path traversal, and unexpected writes.
10. Construct the core host with the verified artifact and provider identity,
    and set `RequireEvidence` and `RequireLimits` in production.
11. Start the host, run the [contract TCK](10-plugin-authoring.md#conformance-kit)
    for a new host implementation, and enforce the lifecycle.
12. Record durable evidence before and after the run.

## Failure Semantics

- Missing, invalid, or revoked signature: do not start the host.
- Missing or mismatched SBOM: do not start the host.
- Artifact digest mismatch: quarantine the artifact and do not start the host.
- Incompatible schema, kind, protocol, isolation, or platform: reject.
- Unsigned artifact under the signed profile: reject. Do not silently downgrade.
- Revocation after start: stop or quarantine according to product policy, and
  record the decision.
- A verification service outage is a failure, not an unsigned fallback.

## SBOM Requirements

- Use SPDX 2.3+ or CycloneDX 1.5+.
- Include the artifact digest and every bundled dependency.
- Include license identifiers and, where required, provenance.
- Sign the SBOM or cover it with the release attestation when policy requires it.
- Store the SBOM and its digest with the deployment evidence.
- Reject an SBOM that covers a different artifact digest.

## Evidence to Persist

The product should record, at minimum:

- descriptor hash and canonicalization version
- manifest ID, version, kind, and schema version
- signature algorithm, `keyId`, verification result, and trust-root version
- artifact digest and materialized path
- SBOM digest and policy result
- compatibility decision and granted permissions
- host lifecycle events, resource-limit events, and termination reason
- tenant, workspace, actor, and approval reference

Core hosts emit lifecycle and resource-limit evidence through the configured
sink when `RequireEvidence` is set. They do not create a durable audit log.

## Handoff Checklist

- [ ] descriptor and artifacts fetched from a trusted source
- [ ] `ParseManifest` and `Validate` pass
- [ ] signed profile enforced; unsigned only for explicit local development
- [ ] detached signature verified; algorithm and `keyId` allowed
- [ ] trust root, rotation, and revocation checked
- [ ] artifact digest matches the signed descriptor and SBOM
- [ ] SBOM policy passes; SBOM digest recorded
- [ ] schema, kind, protocol, isolation, core version, and platform compatible
- [ ] permissions bound to tenant/workspace; no ambient env
- [ ] artifact materialized read-only at a content-addressed path
- [ ] host constructed with verified identity and evidence/resource requirements
- [ ] TCK passed for a new host implementation
- [ ] durable evidence recorded before and after the run

## Core Limits

- `pkg/plugin` does not fetch artifacts, resolve requirements, or call a trust
  store.
- `ValidateTrust` checks presence, not cryptographic validity.
- Core provides process and WASM hosts. Container isolation and container image
  verification are product-owned.
- Process hosts apply `Limits.ResourceLimits`. WASM hosts use
  `MaxMemoryPages` and `MaxConcurrency`, so products must map manifest limits to
  host configuration.
- Core does not enforce the full network permission model. Products must
  enforce egress policy.
- The process host token is passed by environment, never argv. Products still
  own secret storage and rotation.
- A plugin host starting successfully is not proof of trust, SBOM compliance, or
  production isolation.

## Example

```go
manifest, err := plugin.ParseManifest(raw)
if err != nil {
    return err
}
if err := manifest.ValidateTrust(plugin.TrustSigned); err != nil {
    return err
}
if err := verifier.Verify(ctx, raw, manifest.Signature); err != nil {
    return err
}
if err := sbom.Verify(manifest.SBOM, artifactDigest); err != nil {
    return err
}
path, err := materializer.Put(ctx, artifact)
if err != nil {
    return err
}
host, err := process.New(process.Config{
    PluginID:       manifest.ID,
    Provider:       provider,
    Path:           path,
    Sink:           evidenceSink,
    RequireEvidence: true,
    RequireLimits:   true,
    Limits:          manifest.Limits.ResourceLimits(),
})
if err != nil {
    return err
}
if err := host.Start(ctx); err != nil {
    return err
}
defer host.Stop(ctx)
```

The verifier, SBOM policy, trust store, materializer, and evidence sink are
product components. The example only shows the handoff point.

## Non-Goals

- A framework trust store, signature service, or SBOM database.
- Container image materialization or isolation in core.
- Network egress enforcement for plugins.
- A claim that an unsigned local-development profile is production-safe.
