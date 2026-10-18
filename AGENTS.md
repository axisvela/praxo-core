# AGENTS.md

Guidance for coding agents working in PRAXO-CORE (MIT, public).

## Purpose

PRAXO-CORE is the reusable agent framework behind PRAXOVELA. It is not the
PRAXOVELA product and not the COORDIVELA coordination control plane.

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
- Publish a compatibility note when a consumer (PRAXOVELA, COORDIVELA) upgrades.
