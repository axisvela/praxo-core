# Examples

This directory holds Go reference examples and cross-language integration
examples. Language-specific examples live under
`language/<language>/examples/` so they are included in the dedicated language
mirror repositories.

## First Agent

- [Live Model Golden Path](live-model/README.md): published packages connected
  to an OpenAI-compatible endpoint.
- [Quickstart](quickstart/): Go reference endpoint example.

## Build a Prototype

- [Workspace agent](workspace-agent/): read-only published-package Go application.
- [Reference agent](reference/): workspace-oriented reference application.
- [Governed workspace](governed-workspace/): policy and approval boundaries.
- [Checkpoint](checkpoint/): checkpoint store usage.
- [Plugin](plugin/): plugin host and example plugin.
- [Multi-agent](multiagent/): local delegation patterns.
- [Recipes](recipes/): focused integration recipes.
- [Ecosystem](ecosystem/): optional ecosystem adapters.

## By Language

| Language | Examples |
| --- | --- |
| Go | [live-model](live-model/go), [consumer](consumer-go), and this directory |
| Python | [language/python/examples](../language/python/examples) |
| TypeScript | [language/typescript/examples](../language/typescript/examples) |
| Java | [language/java/examples](../language/java/examples) |
| Ruby | [language/ruby/examples](../language/ruby/examples) |
| PHP | [language/php/examples](../language/php/examples) |
| Elixir | [language/elixir/examples](../language/elixir/examples) |
| Lua | [language/lua/examples](../language/lua/examples) |

Each language example directory has its own README with install and run
commands. Published-package examples do not require a repository checkout.
