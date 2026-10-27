# Prolog Bridge Parity

- Tier: bridge
- SPEC_VERSION: 0.2.0

Released source tag `prolog/v0.1.0`. The SWI-Prolog wrapper forwards to the
maintained runtime and passes local forwarding, UTF-8, error, and exit-code
checks. Remote CI and package-registry publication are not claimed. These rows
cover the bridge command surface, not an independent agent loop.

| Go symbol | Prolog symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `praxo-bridge toolcall parse` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `praxo-bridge toolcall strip` | partial | P1 |
| `tool/jsonschema.Schema` | `praxo-bridge jsonschema validate` | partial | P1 |
| `plugin.ParseManifest` | `praxo-bridge plugin validate` | partial | P1 |
| `agent.Agent` | `praxo-bridge run` | partial | P1 |
| `event.Sink` | `praxo-bridge event stream` | partial | P1 |
