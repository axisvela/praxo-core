# 适配器状态

本页跟踪 Model provider、MCP tool session 与 Harmovela 事件投递的原生适配器覆盖。
契约一致性与行为覆盖是独立维度；适配器存在不等于生产或 provider 证据。

状态词：

- `native`：该实现有树内适配器。
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
| PowerShell | inherited | 使用 C# Core |
| Visual Basic / F# | inherited | C# Core 上的示例 |
| Kotlin / Scala / Groovy / Clojure | inherited | Java Core 上的示例 |
| JavaScript | inherited | TypeScript Core 上的示例 |
| Shell / Lisp / Tcl / Prolog | bridge | 通过 bridge 使用 Go Core |
| R | not implemented | 第 2 批 |
| Erlang | not implemented | 第 2 批 |
| Julia | not implemented | 第 2 批 |
| Nim | not implemented | 第 2 批 |
| V | not implemented | 第 2 批 |
| Dart | not implemented | 需要 async model 路径或同步 HTTP helper |
| Haskell | not implemented | 需要决定 HTTP 客户端依赖 |
| Swift | not implemented | 第 3 批 |
| OCaml | not implemented | 第 3 批 |
| Delphi / Free Pascal | not implemented | 第 3 批 |
| Objective-C | not implemented | 第 3 批 |
| MATLAB / Octave | not implemented | 第 3 批 |
| Zig | not implemented | 第 3 批 |
| C | not implemented | 需要 HTTP/JSON 依赖决策 |
| C++ | not implemented | 需要 HTTP/JSON 依赖决策 |
| Fortran | not implemented | 需要 HTTP/JSON 依赖决策 |
| COBOL | not implemented | 需要 HTTP/JSON 依赖决策 |

基线映射见 [OpenAI 兼容模型适配器](../reference/openai-compatible-adapter.md)。

## MCP

| 语言 | 状态 | 说明 |
| --- | --- | --- |
| Go | native | `adapters/mcp` |
| 其他实现 | not implemented | 模型基线之后的下一条适配器主线 |

MCP 支持指最小 client session：initialize、分页 tools/list 与 tools/call。它不代表
托管 MCP 服务、schema 晋级或生产认证。

## Harmovela

| 语言 | 状态 | 说明 |
| --- | --- | --- |
| Go | native | `adapters/harmovela` |
| 其他实现 | not implemented | 在 MCP 主线之后补原生 HTTP event sink |

Harmovela 支持指按文档 envelope POST 事件的 HTTP sink。它不代表认证、投递保证或
生产传输。

## 新增原生适配器

1. 使用该语言已有的 model/tool/event 接缝；不要为了移植扩大 Go API。
2. 用注入 transport 或 loopback fixture 增加确定性测试。
3. 更新本页与语言 README 或 REGISTRY 条目。
4. 运行该语言的 conformance、API snapshot 与原生测试。
5. 明确 streaming、依赖和 provider 验证限制。
