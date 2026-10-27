# MATLAB/Octave Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

Released source tag `matlab/v0.1.0`. Local Octave checks cover toolcall, JSON
Schema, plugin, and agent-loop vector groups. MATLAB itself and remote CI for the
loop are not yet verified. These partial rows do not claim full reference parser
or schema behavior.

| Go symbol | MATLAB/Octave symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `praxo.parse_tool_call` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `praxo.strip_tool_call_markup` | partial | P1 |
| `tool/jsonschema.Schema` | `praxo.validate_schema` | partial | P1 |
| `plugin.ParseManifest` | `praxo.validate_manifest` | partial | P1 |
| `agent.Agent` | `praxo.agent_run` | partial | P1 |

Typed JSON helpers are implementation-local utilities. See
`language/matlab/README.md` for numeric, Unicode, pattern, security, and runtime limits.
