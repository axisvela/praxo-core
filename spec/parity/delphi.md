# Delphi / Free Pascal Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

Released source tag `delphi/v0.1.0`. Local checks use Free Pascal 3.2.2 on
Windows i386 and cover the `toolcall`, `jsonschema`, `plugin`, and `agent-loop`
vector groups. The commercial Delphi compiler and remote CI for the loop are not
yet verified. These partial rows do not claim full reference parser, schema, or
Framework behavior.

| Go symbol | Delphi/Free Pascal symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `PraxoParseToolCall` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `PraxoStripToolCallMarkup` | partial | P1 |
| `tool/jsonschema.Schema` | `PraxoValidateSchema` | partial | P1 |
| `plugin.ParseManifest` | `PraxoValidateManifest` | partial | P1 |
| `agent.Agent` | `PraxoRunAgent` | partial | P1 |

Typed JSON helpers are implementation-local utilities. See
`language/delphi/README.md` for UTF-8, number, pattern, duplicate-field, and
runtime limits.
