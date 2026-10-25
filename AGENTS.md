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
- Keep source files under 500 lines; split by responsibility instead of growing
  a single file.
- Do not add code comments unless asked.

## Multilingual SDKs

- `spec/` is the normative contract for the Python, TypeScript, and Java SDKs.
- Go remains the reference implementation; do not widen the `pkg/...` API for an
  SDK.
- A wire change (JSON field, event, stream kind, plugin envelope, error code)
  must update `spec/` and is breaking for every SDK.
- Add a `spec/parity.md` row for every new contract symbol.
- An SDK change is done only when its conformance vectors and parity linter
  pass.
- Keep every SDK MIT; review dependency licenses before adopting one.
- See `docs/17-multilingual-sdk.md` and `docs/18-multilingual-roadmap.md`.
- New languages follow the tier model in `docs/19-language-expansion.md`; do
  not hand-write a new agent loop without a named consumer.

## Build And Test

```bash
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
cd python; python conformance/run.py
cd python; python api-snapshot.py --check
cd python; python -m unittest discover -s tests -v
cd typescript; npm ci
cd typescript; npm run build
cd typescript; npm run api:check
cd typescript; npm run conformance
cd typescript; node --test tests/sdk.test.js tests/openaicompat.test.js
cd java; mvn -q -DskipTests test-compile
cd java; mvn -q -DskipTests package
cd java; java -cp target/classes io.axisvela.praxo.conformance.ApiSnapshot --check
cd java; java -cp target/classes io.axisvela.praxo.conformance.Run
cd java; java --add-modules jdk.httpserver -cp target/classes:target/test-classes io.axisvela.praxo.adapters.OpenAICompatibleSelfTest
cd java; java -cp target/classes:target/test-classes io.axisvela.praxo.agent.AgentConcurrencySelfTest
cd rust; cargo test
cd rust; cargo run --quiet --bin conformance
```

## Compatibility

- Framework versions start at `0.x`.
- PRAXOVELA product versions are independent.
- Breaking changes require a minor bump before `1.0.0`.
- Publish a compatibility note when a consumer (PRAXOVELA or an external
  product) upgrades.
