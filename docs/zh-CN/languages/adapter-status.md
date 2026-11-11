# 适配器状态

本页跟踪 Model provider、MCP tool session 与 Harmovela 事件投递的原生适配器覆盖。
契约一致性与行为覆盖是独立维度；适配器存在不等于生产或 provider 证据。

状态词：

- `native`：该实现有树内适配器。
- `native (transport seam)`：树内完成请求/响应映射，但 HTTP transport 由调用方提供。
- `inherited`：通过另一个 Core 运行时继承。
- `bridge`：通过 bridge 运行 Go Core。
- `not implemented`：没有适配器，不得声明支持。

## 模型（OpenAI 兼容）

| 语言 | 状态 | 说明 |
| --- | --- | --- |
| Go | native | `adapters/openaicompat` |
| Python | native | `praxo.adapters.openaicompat` |
| TypeScript | native | `src/adapters/openaicompat.ts` |
| Java | native | `adapters.OpenAICompatibleModel` |
| Rust | native | `openai_compat` |
| C# | native | `Praxo.Core.OpenAiCompatible` |
| Ruby | native | `Praxo::Adapters::OpenAICompatible` |
| PHP | native | `Praxo\Core\Adapters\OpenAICompatible` |
| Elixir | native | `Praxo.OpenAICompatible` |
| Lua | native | `praxo.openai_compatible` |
| Perl | native | `Praxo::Adapters::OpenAICompatible` |
| Nim | native | `praxo/adapters/openai_compatible` |
| R | native | `openai_compatible` adapter |
| Erlang | native | `praxo_openai_compatible` |
| Julia | native | `OpenAICompatibleModel` |
| V | native | `praxo.openaicompat`；本机无 V 工具链，由 CI 验证 |
| Dart | native | `OpenAiCompatibleModel`，同步与异步 transport |
| Haskell | native (transport seam) | 调用方提供 `Transport`，不内置 HTTP client |
| Swift | native | `OpenAICompatibleModel`，使用 URLSession transport |
| OCaml | native (transport seam) | 调用方提供 `transport`，不内置 HTTP client |
| Delphi / Free Pascal | native | `TPraxoOpenAIAdapter`，FPC HTTP transport |
| Objective-C | native | `PXROpenAIGenerate`，可注入 transport |
| MATLAB | native | `praxo.openai_compatible`，使用 `webwrite` |
| GNU Octave | native | 共享 `praxo.openai_compatible` 实现 |
| Zig | native | `openaicompat.Adapter`，使用 `std.http` |
| C | native (transport seam) | `PxOpenAICompatible`；调用方提供 HTTP transport |
| C++ | native (transport seam) | `OpenAICompatible`；调用方提供 HTTP transport |
| Fortran | native (transport seam) | `openai_compatible`；调用方提供 HTTP transport |
| D | native (transport seam) | `OpenAICompatibleModel`；可注入 transport |
| COBOL | not implemented | 无 HTTP transport；model callback 缺少工具与历史 |
| PowerShell | inherited | 使用 C# Core |
| Visual Basic / F# | inherited | C# Core 上的示例 |
| Kotlin / Scala / Groovy / Clojure | inherited | Java Core 上的示例 |
| JavaScript | inherited | TypeScript Core 上的示例 |
| Shell / Lisp / Tcl / Prolog | bridge | 通过 bridge 使用 Go Core |

基线映射见 [OpenAI 兼容模型适配器](../reference/openai-compatible-adapter.md)。

## 模型（Anthropic 原生）

| 语言 | 状态 | 说明 |
| --- | --- | --- |
| Go | native | `adapters/anthropic` |
| Python | native | `praxo.adapters.anthropic.AnthropicModel` |
| TypeScript | native | `src/adapters/anthropic.ts` |
| C# | native | `Praxo.Core.AnthropicModel` |
| R | native (transport seam) | `anthropic`；调用方可提供 `transport` |
| Elixir | native | `Praxo.Anthropic` |
| Java | native | `adapters.AnthropicModel` |
| Rust | native (transport seam) | `adapters::anthropic`；调用方提供 transport |
| Ruby | native | `Praxo::Adapters::Anthropic`；可注入 transport |
| PHP | native | `Praxo\Core\Adapters\Anthropic` |
| Lua | native | `praxo.adapters.anthropic` |
| Perl | native | `Praxo::Adapters::Anthropic` |
| Dart | native | `AnthropicModel`，同步与异步 transport |
| Erlang | native | `praxo_anthropic` |
| D | native (transport seam) | `AnthropicModel`；可注入 transport |
| C | native (transport seam) | `PxAnthropic`；调用方提供 HTTP transport |
| C++ | native (transport seam) | `Anthropic`；调用方提供 HTTP transport |
| Fortran | native (transport seam) | `anthropic_compatible`；调用方提供 HTTP transport |
| 其他实现 | not implemented | 仅 OpenAI-compatible 端点使用 OpenAI 兼容适配器 |

## 模型（Gemini 原生）

| 语言 | 状态 | 说明 |
| --- | --- | --- |
| Go | native | `adapters/gemini` |
| Python | native | `praxo.adapters.gemini.GeminiModel` |
| TypeScript | native | `src/adapters/gemini.ts` |
| C# | native | `Praxo.Core.GeminiModel` |
| R | native (transport seam) | `gemini`；调用方可提供 `transport` |
| Elixir | native | `Praxo.Gemini` |
| Java | native | `adapters.GeminiModel` |
| Rust | native (transport seam) | `adapters::gemini`；调用方提供 transport |
| Ruby | native | `Praxo::Adapters::Gemini`；可注入 transport |
| PHP | native | `Praxo\Core\Adapters\Gemini` |
| Lua | native | `praxo.adapters.gemini` |
| Perl | native | `Praxo::Adapters::Gemini` |
| Dart | native | `GeminiModel`，同步与异步 transport |
| Erlang | native | `praxo_gemini` |
| D | native (transport seam) | `GeminiModel`；可注入 transport |
| C | native (transport seam) | `PxGemini`；调用方提供 HTTP transport |
| C++ | native (transport seam) | `Gemini`；调用方提供 HTTP transport |
| Fortran | native (transport seam) | `gemini_compatible`；调用方提供 HTTP transport |
| 其他实现 | not implemented | 原生 generateContent 映射按采用顺序推进 |

## MCP

| 语言 | 状态 | 说明 |
| --- | --- | --- |
| Go | native | `adapters/mcp` |
| Python | native | `praxo.adapters.mcp.MCPClient`；stdio JSON-RPC，含 fake server 测试 |
| TypeScript | native | `src/adapters/mcp.ts`；stdio JSON-RPC，含 fake server 测试 |
| Java | native | `adapters.McpClient`；stdio JSON-RPC，含 fake server self-test |
| Rust | native | `mcp::McpClient`；stdio JSON-RPC，含 fake server 测试 |
| C# | native | `Praxo.Core.Adapters.McpClient`；stdio JSON-RPC，含 fake server 测试 |
| R | native (transport seam) | `mcp_client`；base R 的 stdio 需要调用方提供 transport |
| Elixir | native | `Praxo.Mcp`；stdio JSON-RPC，含 fake server 测试 |
| Ruby | native | `Praxo::Adapters::MCPClient`；stdio JSON-RPC，可注入 IO |
| PHP | native | `Praxo\Core\Adapters\MCPClient`；stdio JSON-RPC |
| Dart | native | `McpClient`；stdio JSON-RPC，支持同步/异步 transport seam |
| Erlang | native | `praxo_mcp`；stdio JSON-RPC，可注入 transport |
| Lua | native (transport seam) | `praxo.adapters.mcp`；调用方提供 transport |
| 其他实现 | not implemented | 按采用顺序补齐原生 MCP client |

MCP 支持指最小 client session：initialize、分页 tools/list 与 tools/call。它不代表
托管 MCP 服务、schema 晋级或生产认证。Python/TypeScript 是 stdio 试点；未声明真实
MCP 服务或远端 transport。

## Harmovela

| 语言 | 状态 | 说明 |
| --- | --- | --- |
| Go | native | `adapters/harmovela` |
| Python | native | `praxo.adapters.harmovela.HarmovelaSink` |
| TypeScript | native | `src/adapters/harmovela.ts` |
| Java | native | `adapters.HarmovelaSink` |
| Rust | native | `harmovela::Sink` |
| C# | native | `Praxo.Core.HarmovelaSink` |
| R | native | `harmovela_sink` |
| Elixir | native | `Praxo.HarmovelaSink` |
| Ruby | native | `Praxo::Adapters::HarmovelaSink` |
| PHP | native | `Praxo\Core\Adapters\HarmovelaSink` |
| Lua | native | `praxo.harmovela_sink` |
| Nim | native | `newHarmovelaSink` |
| Perl | native | `Praxo::Adapters::Harmovela` |
| Erlang | native | `praxo_harmovela` |
| Julia | native | `HarmovelaSink` |
| V | native | `harmovela_sink`；本机无 V 工具链，由 CI 验证 |
| D | native | `HarmovelaSink` |
| Dart | native | `HarmovelaSink` |
| Haskell | native (transport seam) | `Praxo.Harmovela`；调用方提供 transport |
| Swift | native | `HarmovelaSink`，使用 URLSession transport |
| OCaml | native (transport seam) | `harmovela_sink`；调用方提供 transport |
| Delphi / Free Pascal | native | `TPraxoHarmovelaSink` |
| Objective-C | native | `PraxoHarmovela` |
| MATLAB | native | `praxo.harmovela_sink` |
| GNU Octave | native | 共享 `praxo.harmovela_sink` |
| Zig | native | `harmovela` |
| C | native (transport seam) | `praxo_harmovela`；调用方提供 HTTP transport |
| C++ | native (transport seam) | `HarmovelaSink`；调用方提供 HTTP transport |
| Fortran | native (transport seam) | `harmovela`；调用方提供 HTTP transport |
| PowerShell | inherited | 使用 C# Core |
| COBOL | not implemented | 无 HTTP transport；无 event sink 集成 |
| 其他实现 | not implemented | 在有命名消费者或维护者时补齐 |

Harmovela 支持指按文档 envelope POST 事件的 HTTP sink。它不代表认证、投递保证、排序
或生产传输。各实现测试使用注入 transport 或 loopback fixture；未声明真实 Harmovela
服务。

## 新增原生适配器

1. 使用该语言已有的 model/tool/event 接缝；不要为了移植扩大 Go API。
2. 用注入 transport 或 loopback fixture 增加确定性测试。
3. 更新本页与语言 README 或 REGISTRY 条目。
4. 运行该语言的 conformance、API snapshot 与原生测试。
5. 明确 streaming、依赖和 provider 验证限制。
