# PowerShell Bridge Parity

- Tier: bridge
- SPEC_VERSION: 0.2.0

| Go symbol | PowerShell symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `Invoke-PraxoBridge toolcall parse` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `Invoke-PraxoBridge toolcall strip` | partial | P1 |
| `tool/jsonschema.Schema` | `Invoke-PraxoBridge jsonschema validate` | partial | P1 |
| `plugin.ParseManifest` | `Invoke-PraxoBridge plugin validate` | partial | P1 |
| `agent.Agent` | `Invoke-PraxoBridge run` | partial | P1 |
| `event.Sink` | `Invoke-PraxoBridge event stream` | partial | P1 |
