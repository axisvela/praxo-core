# C# Parity

- Tier: core
- SPEC_VERSION: 0.2.0

The C# core passes all eleven vectors and checks a public API snapshot. The
rows below map the implemented surface to the Go reference. `partial` means the
C# API covers the vector behavior and the common path, but not every optional
Go hook or adapter feature.

| Go symbol | C# symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `ToolCallParser.Parse` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `ToolCallParser.StripMarkup` | partial | P1 |
| `toolcall.ParseInputJSON` | `ToolCallParser.ParseInputJson` | partial | P1 |
| `tool/jsonschema.Schema` | `JsonSchema.Validate` | partial | P1 |
| `plugin.ParseManifest` | `Plugin.ParseManifest` | partial | P1 |
| `policy.NewPathChecker` | `PathChecker` constructor | parity | P1 |
| `memory.NewMemoryStore` | `InMemoryMemoryStore` constructor | parity | P1 |
| `event.Event` | `Event` | parity | P1 |
| `event.MultiSink` | `MultiSink` | parity | P1 |
| `event.FilterSink` | `FilterSink` | parity | P1 |
| `agent.New` | `Agent` constructor | partial | P1 |
| `agent.Result` | `RunResult` | partial | P1 |
| `agent.EstimateTokens` | `ContextEstimator.EstimateTokens` | parity | P1 |
| `agent.StructuredOutput` | `StructuredOutput` | partial | P1 |
| `agent.PIIRedactor` | `PiiRedactor` | parity | P1 |
| `agent.PIIRule` | `PiiRule` | parity | P1 |
| `agent.FallbackModel` | `ModelFallback.Fallback` | parity | P1 |
