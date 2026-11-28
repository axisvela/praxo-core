# PRAXO-CORE Roadmap

Current core release: `2.11.3`.

The [public roadmap](docs/project/planning/roadmap.md) organizes current work around
developer outcomes. It is not a delivery schedule.

The next-stage direction is practical adoption: help developers choose the
framework, run a useful agent from a published package, build a coherent
prototype, embed it in an application, and only then apply broader hardening and
verification. Advanced integrations remain demand-driven.

The next delivery priority is ecosystem-native reference applications, ordered
PHP (Drupal/Laravel), Java (Spring Boot), Elixir/Erlang (OTP), Go
(infrastructure), C++/Rust (edge/embodied), COBOL (batch exceptions), Julia
(scientific computing/optimization), then Ruby (Rails). All eight priorities have
source implementations, not full portfolio acceptance or parallel delivery promises.
PHP has passing application CI; Java has a scoped hosted deterministic CI pass
(2026-11-28), not live-model verification; C++ is build-only, and
Go/Rust use local source dependencies. Seven reference applications have hosted
live-model runs; these do not verify the separate published-package starter path.
A bounded coding-agent selection benchmark supports those paths; it does not
precede their delivery.

The roadmap covers the Go reference and the independently versioned language
SDKs. Examples, installation paths, and feature availability must state their
target language instead of assuming Go.

- [Next-stage direction](docs/project/planning/roadmap.md#next-stage-direction)
- [Language scope](docs/project/planning/roadmap.md#language-scope)
- [Developer adoption path](docs/project/planning/roadmap.md#adoption-path)
- [Current priorities](docs/project/planning/roadmap.md#current-priorities)
- [Reference application portfolio](docs/project/status/delivery-history.md#reference-application-portfolio)
- [AI-native reference application design](docs/project/planning/ai-native-reference-applications.md)
- [Adoption evidence](docs/project/status/delivery-history.md#adoption-evidence)
- [Language implementations](docs/languages/index.md)
- [Coding-agent adoption baseline protocol](docs/project/evaluation/adoption-baseline.md)
- [Release history](docs/releases/index.md)
- [Complete changelog](CHANGELOG.md)
- [SDK support and distribution](docs/languages/support.md)
- [When not to use PRAXO-CORE](docs/getting-started/when-not-to-use.md)
- [Language implementation policy](docs/contributing/language-policy.md)
- [Governed execution design](docs/reference/governed-execution.md)
- [Standard Embedding and execution profiles](docs/reference/execution-profiles.md)
- [Embodied integration design](docs/reference/embodied-integration.md)
- [Verification and hardening status](docs/project/evaluation/verification-evidence.md)
- [Compatibility policy](docs/project/status/compatibility-policy.md)
- [Ecosystem boundaries](docs/project/planning/roadmap.md#ecosystem-boundaries)
