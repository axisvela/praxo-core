# Security Policy

PRAXO-CORE is a framework, not a product. Signature trust, tenant policy,
credential storage, and plugin materialization belong to the embedding product
(PRAXOVELA) or the external integrator.

## Supported Versions

| Version | Support |
| --- | --- |
| `0.16.x` | current pre-1.0 line |
| `1.0.x` | security fixes after release |
| older `0.x` | upgrade to the current line |

## Reporting a Vulnerability

Do not open a public issue for a vulnerability. Use the repository's private
security advisory feature:

`https://github.com/axisvela/praxo-core/security/advisories/new`

Include the affected package, version, a minimal reproducer, and the impact.
Reports are handled on a best-effort basis; no SLA is promised for the `0.x`
line.

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

See [docs/08-security.md](docs/08-security.md) for the framework threat model
and known limitations.
