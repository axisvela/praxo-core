# PHP Parity

- Tier: core
- SPEC_VERSION: 0.2.0

The PHP core passes all eleven vectors, its dependency-free tests, and its API
snapshot. `partial` marks a surface that covers the vector behavior and common
path, but not every optional Go hook or provider adapter.

| Go symbol | PHP symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `ToolCallParser::parse` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `ToolCallParser::stripMarkup` | partial | P1 |
| `toolcall.ParseInputJSON` | `ToolCallParser::parseInputJson` | partial | P1 |
| `tool/jsonschema.Schema` | `JsonSchema::validate` | partial | P1 |
| `plugin.ParseManifest` | `Plugin::parseManifest` | partial | P1 |
| `policy.NewPathChecker` | `PathChecker::__construct` | parity | P1 |
| `memory.NewMemoryStore` | `InMemoryMemoryStore::__construct` | parity | P1 |
| `memory.MemoryStore` | `InMemoryMemoryStore` | parity | P1 |
| `event.Event` | `Event` | parity | P1 |
| `event.MultiSink` | `MultiSink` | parity | P1 |
| `event.FilterSink` | `FilterSink` | parity | P1 |
| `agent.New` | `Agent::__construct` | partial | P1 |
| `agent.Result` | `RunResult` | partial | P1 |
| `agent.ContextBudget` | `ContextBudget` | parity | P1 |
| `agent.EstimateTokens` | `ContextEstimator::estimateTokens` | parity | P1 |
| `agent.StructuredOutput` | `StructuredOutput` | partial | P1 |
| `agent.PIIRedactor` | `PiiRedactor` | parity | P1 |
| `agent.PIIRule` | `PiiRule` | parity | P1 |
| `agent.FallbackModel` | `ModelFallback::fallback` | parity | P1 |
