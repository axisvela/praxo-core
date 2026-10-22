# Adoption Plan

**Status:** 90-day plan for the `2.1.0` cycle.

## Goal

Make it easy for a Go team to go from discovery to a first successful run in
under ten minutes, and then to a production integration without forking the
framework.

## Metrics

- time to first successful run
- quickstart success reports
- number of external integrators
- issue and PR response time
- adapter coverage (OpenAI-compatible, MCP, AxisVela)
- docs coverage and broken-link count

Avoid vanity metrics such as stars; track them only as a lagging signal.

## Workstreams

### Release

- Tag `v2.1.0` with the adapter and docs surface.
- Tag `adapters/mcp/v0.1.0` separately.
- Adopt a monthly minor cadence with a release checklist.
- Keep `pkg/...` frozen; additive work goes into adapters, examples, and docs.

### Try

- Keep the one-command quickstart working against Ollama.
- Maintain the reference workspace agent.
- Keep the docs site, recipes, and adoption guide current.
- Add a smoke test for every runnable example.

### Integrate

- OpenAI-compatible and MCP adapters.
- NOETIVELA, Mnemovela, and GNOSIVELA SDK recipes.
- Evaluate native Anthropic and Gemini adapters.
- Add Harmovela, AEGIVELA, LIMENORA, and RHEOVELA recipes.

### Prove

- Publish benchmark methodology and regression results.
- Add an OpenTelemetry event sink.
- Document a production case study when an external integrator is ready.
- Keep the security model and compatibility gates current.

### Community

- Keep issue and PR templates actionable.
- Label and curate good first issues.
- Use Discussions for design questions.
- Publish a short monthly roadmap update.

## 30 / 60 / 90 Days

### Days 0-30

- Release `v2.1.0` and `adapters/mcp/v0.1.0`.
- Publish the launch post and GitHub release notes.
- Seed five good first issues.
- Collect quickstart feedback and fix the top three blockers.
- Add docs analytics or a lightweight feedback link.

### Days 31-60

- Evaluate native Anthropic and Gemini adapters.
- Add MCP resources, prompts, and streaming progress.
- Add an OpenTelemetry event sink.
- Publish Harmovela, AEGIVELA, and LIMENORA recipes.
- Create a case-study template.

### Days 61-90

- Release `v2.2.0` with the highest-value provider/protocol work.
- Publish a reproducible benchmark note.
- Publish one external case study or integration story.
- Host a community roadmap discussion.
- Start a community-maintained adapter index.

## Launch Channels

- GitHub release and Discussions
- Go Weekly and Golang Weekly
- Reddit r/golang
- Hacker News Show HN
- X and LinkedIn
- AxisVela product channels

## Content Calendar

| Week | Content |
| --- | --- |
| 1 | Build a governed agent in 10 minutes |
| 2 | PRAXO-CORE vs LangChainGo, Eino, and ADK Go |
| 3 | MCP tools with policy and audit |
| 4 | NOETIVELA, Mnemovela, and GNOSIVELA integration |
| 6 | Benchmark methodology and results |
| 8 | Reference workspace agent walkthrough |

## Risks

- **GNOSIVELA has no v3 semver tag.** Pin a pseudo-version and update when a tag
  lands.
- **MCP SDK churn.** Keep the MCP adapter in a separate module and pin versions.
- **Provider fragmentation.** Prefer OpenAI-compatible coverage first, then add
  native adapters based on demand.
- **Overclaiming.** Keep comparisons and compatibility notes factual and dated.

## Current Status

- [x] OpenAI-compatible adapter with streaming
- [x] MCP tool gateway module
- [x] Quickstart and reference app
- [x] NOETIVELA, Mnemovela, and GNOSIVELA SDK recipes
- [x] Bilingual docs site and adoption guide
- [x] Benchmarks and CI smoke run
- [ ] `v2.1.0` tag
- [ ] Launch announcement
- [ ] First external case study
