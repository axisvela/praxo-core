# PRAXO-CORE Swift

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core-swift`
- registry: [Swift Package Index](https://swiftpackageindex.com/axisvela/praxo-core-swift)
- source_version: `0.4.0`
- published_version: `0.2.0`
- install_published: `.package(url: "https://github.com/axisvela/praxo-core-swift.git", from: "0.2.0")`
- install_source: `.package(url: "https://github.com/axisvela/praxo-core-swift.git", from: "0.4.0")`
- source_tag: `swift/v0.4.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/swift/

## Capabilities and Status

- OpenAI-compatible model: native (`OpenAICompatibleModel` with URLSession transport)
- Anthropic model: native (`AnthropicModel` with injectable transport)
- Gemini model: native (`GeminiModel` with injectable transport)
- MCP client: native (`McpClient`, `StdioMcpTransport`, `HttpMcpTransport`; typechecked locally, full build blocked)
- Harmovela sink: native (`HarmovelaSink` with URLSession transport)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
