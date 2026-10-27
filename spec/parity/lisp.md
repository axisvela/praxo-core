# Lisp Bridge Parity

- Tier: bridge
- SPEC_VERSION: 0.2.0

Unreleased Common Lisp bridge over the maintained runtime. Local SBCL 2.6.9
checks cover forwarding, UTF-8 JSON, error output, and exit codes. Linux CI and
consumer evidence remain pending. These rows cover the bridge command surface,
not an independent agent loop.

| Go symbol | Lisp symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `praxo-bridge toolcall parse` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `praxo-bridge toolcall strip` | partial | P1 |
| `tool/jsonschema.Schema` | `praxo-bridge jsonschema validate` | partial | P1 |
| `plugin.ParseManifest` | `praxo-bridge plugin validate` | partial | P1 |
| `agent.Agent` | `praxo-bridge run` | partial | P1 |
| `event.Sink` | `praxo-bridge event stream` | partial | P1 |
