# AGENTS.md

Guidance for coding agents working in PRAXO-CORE (MIT, public).

## Purpose

PRAXO-CORE is the reusable agent framework behind PRAXOVELA. It is not the
PRAXOVELA product. COORDIVELA is an independent product and does not consume
this framework.

## Documentation Location

- Public framework documents: `docs/` in this repository.
- Internal extraction plan, source mapping, product-family sequencing, and
  PRAXOVELA split decisions: `PRAXOVELA-EE/docs/praxo-core/`.
- COORDIVELA documents: `COORDIVELA/docs/` and `COORDIVELA-ee/docs/`.
- Do not add product-family planning or enterprise-only material to this public
  repository.

## Guardrails

- Keep the public API small and documented.
- Do not import AGPL-only packages; this repository must remain MIT.
- Do not copy third-party code without compatible licensing and notices.
- Keep provider credentials, tenant data, and secrets outside the framework.
- Preserve provenance in `docs/04-license-and-provenance.md`.
- Add tests for every exported interface and loop behavior.
- Prefer interfaces over concrete integrations.
- Do not add code comments unless asked.

## Build And Test

```bash
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
```

## Compatibility

- Framework versions start at `0.x`.
- PRAXOVELA product versions are independent.
- Breaking changes require a minor bump before `1.0.0`.
- Publish a compatibility note when a consumer (PRAXOVELA or an external
  product) upgrades.
