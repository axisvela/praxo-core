# OCaml Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

Released source tag `ocaml/v0.1.0`. Local checks use OCaml 4.14.2 (bytecode)
and the Linux CI job covers the `toolcall`, `jsonschema`, and `plugin` vector
groups. Native compilation and remote CI for the loop are not yet verified.
These partial rows do not claim full reference parser, schema, or Framework
behavior.

| Go symbol | OCaml symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `Praxo.parse_tool_call` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `Praxo.strip_tool_call_markup` | partial | P1 |
| `tool/jsonschema.Schema` | `Praxo.validate_schema` | partial | P1 |
| `plugin.ParseManifest` | `Praxo.validate_manifest` | partial | P1 |
| `agent.Agent` | `Praxo.run_agent` | partial | P1 |

Typed JSON helpers are implementation-local utilities. See
`language/ocaml/README.md` for number, UTF-8, pattern, and runtime limits.
