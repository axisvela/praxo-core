# Changelog

All notable changes to PRAXO-CORE are documented here.

## [Unreleased]

### Added

- Extracted the scheduler engine from PRAXOVELA into `pkg/scheduler` with
  provenance recorded. PRAXOVELA now imports the framework scheduler and keeps
  only a thin product alias.
- Extracted tool-call parsing into `pkg/output` and JSON Schema validation into
  `pkg/tool/schema`. PRAXOVELA now aliases both framework packages.

## [0.1.0] - 2026-10-18

### Added

- MIT-licensed framework baseline.
- Model, tool, memory, event, scheduler, policy, sandbox, and agent primitives.
- Minimal governed agent loop with tool calls, event emission, and policy hooks.
- Echo example and framework documentation.
