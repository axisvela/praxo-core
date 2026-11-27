# PHP Core Release Notes

## 0.10.1 - 2026-11-27

Source tag `php/v0.10.1`.

### Fixed

- Publish a new Packagist tag after the previous split tag reference diverged.
- Refresh the package README with scenario tutorials, reference applications,
  and community links. No API or wire change.

## 0.10.0 - 2026-11-26

Source tag `php/v0.10.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.9.0 - 2026-11-20

Source tag `php/v0.9.0`.

### Added

- `PluginProcessHost` supervises a JSON-Lines plugin child with token
  authentication.

## 0.8.2 - 2026-11-18

Source tag `php/v0.8.2`; Packagist publication follows the split-repository release.

### Added

- Representative-chain, advanced-delegation, and the expanded task-oriented
  example index, including MCP, OTel/Harmovela, and governance checks.
- Registry README links for the current example set.

### Compatibility

- No public API or wire change; `SPEC_VERSION` remains `0.2.0`.


## 0.8.1 - 2026-11-15

### Changed

- Expanded the registry README with a Get started section and a task-oriented example index.

## 0.8.0 - 2026-11-15

Source tag `php/v0.8.0`.

### Added

- Opt-in `requirePolicy` guard: agent construction fails with
  `AGENT_INVALID_OPTIONS` when a policy is required but no policy hook is
  configured.
- Opt-in `requireToolScope` guard: agent construction fails with
  `AGENT_INVALID_OPTIONS` when tool scope is required but `allowedTools` is
  empty.

## 0.7.0 - 2026-11-13

Source tag `php/v0.7.0`.

### Added

- OpenTelemetry event sink (`OtelSink`) over a caller-supplied OTLP/HTTP
  transport.
- Synchronous subagent seam (`SubagentManager`, `SubagentRunner`); PHP has no
  in-process thread manager.
- Retriever seam (`Document`, `Retriever`, `FuncRetriever`).

## 0.6.0 - 2026-11-12

Source tag `php/v0.6.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
- Native Anthropic Messages and Gemini generateContent model adapters.
- Minimal stdio MCP client with pagination, tool calls, timeouts, and
  cancellation notifications.

## 0.4.1 - 2026-11-09

Source release tag `php/v0.4.1`. Packagist publishes
`axisvela/praxo-core==0.4.1` from split tag `v0.4.1`.

### Added

- Optional `Praxo\Core\Adapters\OpenAICompatible` adapter. It is not required
  by the Core and is not included in the `0.4.0` package.

### Fixed

- `composer.json` now declares `src/autoload.php` through `autoload.files`, so a
  Composer consumer loads the SDK classes. Published `0.4.0` does not contain
  this metadata; consumers on `0.4.0` must require the package autoload file
  after `vendor/autoload.php` until `0.4.1` is published.
- The conformance API check reads the snapshot version from `composer.json`
  instead of a hardcoded `0.3.0` path.

### Compatibility

- The new adapter is additive. Existing `0.4.0` classes and methods are
  unchanged; `api/0.4.1.txt` adds only the adapter surface.

## 0.4.0 - 2026-11-02

Source release tag `php/v0.4.0`. Packagist publishes
`axisvela/praxo-core==0.4.0` from split tag `v0.4.0`.

### Added

- Human-in-the-loop interrupt decisions through `AgentOptions::$interruptOn`,
  `$onInterruptDecision`, and `$onInterrupt`.
- `Interrupt`, `InterruptAction`, and `InterruptDecision` with approve/edit/
  reject/respond actions. Interrupted calls emit `tool.interrupt` and edited
  arguments are reauthorized.
- API snapshot `api/0.4.0.txt`.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step. The Packagist package
remains `axisvela/praxo-core@0.1.0` until publication.

### Added

- Caller-provided `batchToolInvoker` and `maxParallelTools` for bounded
  cooperative parallel tool dispatch.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New `AgentOptions` fields are additive.
- The Core does not create threads; the batch invoker owns concurrency and the
  native test uses PHP Fibers.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `php/v0.2.0`. The Packagist package remains
`axisvela/praxo-core@0.1.0` until publication.

### Added

- `Agent::runStream` and streaming model callbacks.
- Cancellation through `AgentOptions::cancellation`.
- `parseSseStream` for OpenAI-compatible SSE streams.
- API snapshot `api/0.2.0.txt`.

### Fixed

- Final tool names are checked against the allowlist, middleware changes are
  reauthorized, and the final registered tool is executed.
- Middleware entered before a startup failure is cleaned up without run events.
- Later after-run callbacks continue after one fails, and cleanup failures after
  success fail the run closed.
- Truncated and half-packet SSE streams are rejected.

### Compatibility

- New options and methods are backward compatible for callers.
- Parallel tool execution remains unsupported: PHP has no standard threads, and pcntl/parallel extensions are not portable across CLI, FPM, and Windows.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## Earlier Releases

See the repository [changelog](../../CHANGELOG.md) for `0.1.x` history.