# Security Policy

PRAXO-CORE is a framework, not a product. Signature trust, tenant policy,
credential storage, and plugin materialization belong to the embedding product
(PRAXOVELA) or the external integrator.

## Supported Versions

| Version | Support |
| --- | --- |
| `2.7.x` | current release line; use the latest patch |
| older `2.x` | upgrade to the current patch line |
| `1.x` and `0.x` | legacy; migrate to v2 for current fixes |

## PHP Runtime Advisory

PRAXO-CORE does not bundle PHP or Brotli. On Windows, use PHP `8.2.35-1`,
`8.3.36-1`, `8.4.27-1`, `8.5.12-1`, or newer patched builds; these builds
include Brotli 1.2.1 and fix CVE-2026-111497, an out-of-bounds write in Brotli
decompression. Linux
distributions and containers may provide equivalent backports; verify their
advisory status before deployment.

## Reporting a Vulnerability

Do not open a public issue for a vulnerability. Use the repository's private
security advisory feature:

`https://github.com/axisvela/praxo-core/security/advisories/new`

Include the affected package, version, a minimal reproducer, and the impact.
Reports are handled on a best-effort basis; no response or backport SLA is promised.

## Scope

In scope:

- `pkg/plugin` and `pkg/plugin/host/{process,wasm}`
- `pkg/policy` path containment
- `pkg/toolcall`, `pkg/plugin/manifest`, and `pkg/tool/jsonschema` parsers
- `pkg/agent` policy/tool enforcement
- `pkg/httpclient` transport behavior

Out of scope for this repository:

- PRAXOVELA product wiring, signature trust stores, tenant policy, and
  materialization
- third-party provider or sandbox implementations
- prompt-injection content that is correctly denied by policy

See [security model](docs/security/index.md) for the framework threat model
and known limitations, [plugin trust and SBOM](docs/security/plugin-trust.md)
for the product-owned plugin verification and SBOM handoff, and
[docs/containment-review.md](docs/security/containment.md) for the internal control
map and residual risks. The containment review is not independent sign-off.
