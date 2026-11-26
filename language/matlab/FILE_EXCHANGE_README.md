# PRAXO-CORE for MATLAB

PRAXO-CORE is an MIT-licensed, embeddable agent framework for MATLAB. This File
Exchange package contains the native `+praxo` Core, runnable examples, and
scenario tutorials.

> **Runtime boundary:** execution evidence currently comes from GNU Octave
> 11.3.0. Native MATLAB release compatibility is not independently verified.
> File Exchange platform labels are not a production support promise.

## Install

Install the toolbox from File Exchange and add it to the MATLAB path. This
package also contains `examples/` and `Tutorial/`; open those folders to run the
source examples.

## Quickstart

```matlab
result = praxo.agent_run('Hi', @(request) struct('content', 'hello'), {}, struct());
disp(result.output)
```

For an OpenAI-compatible endpoint:

```matlab
options = struct('baseUrl', 'https://api.openai.com/v1', ...
    'model', 'gpt-4o-mini', 'apiKey', getenv('PRAXO_API_KEY'));
model = @(request) praxo.openai_compatible(request, options);
result = praxo.agent_run('Hi', model, {}, struct());
```

## Package contents

| Path | Purpose |
| --- | --- |
| `+praxo/` | Native Core: agent loop, tools, policy, memory, checkpoints, events, middleware, HITL, provider adapters, MCP, OTel, retriever, delegation |
| `examples/` | 15 runnable examples covering consumer, live model, service, governance, streaming, checkpoints, MCP, HITL, and delegation |
| `Tutorial/` | Two scenario tutorials: data quality and signal trends |
| `README.md` | This File Exchange introduction |
| `LICENSE` | MIT license |
| `toolbox-image.png` | File Exchange thumbnail |

## Tutorials

| Tutorial | What it shows | Local path | Source |
| --- | --- | --- | --- |
| Data Quality | Fixed mean/median/outlier statistics; Core chooses normal or outlier review without modifying source data | `Tutorial/data-quality` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/data-quality |
| Signal Trends | One fixed `review_signal` tool; bounded metrics and a review-only report with no device control | `Tutorial/signal-trends` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends |

Each tutorial directory has its own README with the exact `octave-cli` or
`matlab -batch` command and expected output.

## Examples

| Example | What it shows | Local path | Source |
| --- | --- | --- | --- |
| Consumer | Deterministic model, tool, and allow/deny | `examples/consumer` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/consumer |
| Live model | OpenAI-compatible endpoint and `get_time` tool | `examples/live-model` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/live-model |
| HTTP service | Transport-neutral request handler | `examples/service` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/service |
| Identity and policy | Trusted principal and tenant checks | `examples/identity-policy` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/identity-policy |
| Structured output | Schema validation and rejection | `examples/structured-output` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/structured-output |
| Streaming | Accumulated output reconstruction | `examples/streaming` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/streaming |
| Retry | Bounded transient retry | `examples/retry` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/retry |
| Provider fallback | Primary failure and fallback | `examples/provider-fallback` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/provider-fallback |
| Checkpoint | Allowlist round trip | `examples/checkpoint` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/checkpoint |
| Session checkpoint | Multi-turn history recovery | `examples/session-checkpoint` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/session-checkpoint |
| Event sink | Filtered sink composition | `examples/event-sink` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/event-sink |
| MCP | Caller-owned MCP-shaped transport | `examples/mcp` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/mcp |
| HITL | Approve, edit, reject, and respond | `examples/hitl` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/hitl |
| Representative chain | MCP, delegation, OTel/Harmovela, denied edit | `examples/representative-chain` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/representative-chain |
| Advanced delegation | Parent/child scope and six governance checks | `examples/advanced-delegation` | https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/advanced-delegation |

## Tutorials, candidate scenarios, and reference applications

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/): delivery standards and the reference-application portfolio.
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/): candidate business goals and related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/): cross-language tutorials, examples, and application paths.
- [Reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio): planned and existing full host integrations.

## Documentation

- Language page: https://axisvela.github.io/praxo-core/languages/matlab/
- Repository: https://github.com/axisvela/praxo-core
- Registry status: https://axisvela.github.io/praxo-core/languages/registry-status/
- Compatibility policy: https://axisvela.github.io/praxo-core/project/compatibility-policy/

## Community

- X: https://x.com/axisvela
- Weibo: https://weibo.com/u/1936025761
- LinkedIn: https://www.linkedin.com/company/axisvela/
- Facebook: https://www.facebook.com/profile.php?id=61596905732406
- YouTube: https://www.youtube.com/@axisvela
- Discord: https://discord.com/channels/1575163993767809064/1575164343148875977
- GitHub Discussions: https://github.com/axisvela/praxo-core/discussions
- GitHub Issues: https://github.com/axisvela/praxo-core/issues
- Documentation: https://axisvela.github.io/praxo-core/
- Architect: https://axisvela.architect.pub

## Limits

- This is an execution framework, not a hosted model, workflow engine, crawler,
  or production sandbox.
- Provider credentials, durable state, and external effect reconciliation remain
  application-owned.
- Checkpoints are recovery hints, not transactions.
- Native MATLAB runtime compatibility remains unverified; current execution
  evidence is GNU Octave 11.3.0.

## License

MIT. See `LICENSE`.
