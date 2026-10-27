# Objective-C Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

Unreleased Wire-stage candidate targeting a native Framework. Local validation
uses clang 21.1.8 with GNUstep Base 1.31.1 on Windows and covers the `toolcall`,
`jsonschema`, and `plugin` vector groups. macOS CI and release review are not
yet verified. These partial rows do not claim a full reference parser, schema
engine, provider adapter, plugin host, or agent loop.

| Go symbol | Objective-C symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `PXRParseToolCall` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `PXRStripToolCallMarkup` | partial | P1 |
| `tool/jsonschema.Schema` | `PXRValidateSchema` | partial | P1 |
| `plugin.ParseManifest` | `PXRParseManifest` | partial | P1 |

The JSON, pattern, and path helpers are implementation-local utilities. See
`language/objc/README.md` for runtime, Unicode, regex, and security limits.
