# 真实模型 Golden Path

这是从已发布 PRAXO-CORE 包连接到真实模型的最短路径。示例使用
OpenAI-compatible 端点、一个低风险 `get_time` 工具，以及只允许 `get_time`
的显式策略。

Go 项目位于
[`language/go/examples/live-model/go`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/live-model/go)。
语言专属项目位于 `language/<lang>/examples/live-model`，例如
[`language/python/examples/live-model`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/live-model)。
这些目录会进入对应语言的专用镜像仓库。

## 前置条件

- 已安装受支持语言的工具链。
- 本地 Ollama，或其他 OpenAI-compatible 端点。
- 不需要检出 PRAXO-CORE 源码。

为 Ollama 安装模型：

```bash
ollama pull llama3.2
```

配置端点：

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
# export PRAXO_API_KEY=...   # 仅托管端点需要
```

PowerShell：

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "llama3.2"
```

## 按语言运行

| 语言 | 包 | 命令 |
| --- | --- | --- |
| Go | `github.com/axisvela/praxo-core/v2@v2.9.0` | `cd language/go/examples/live-model/go; go run .` |
| Python | PyPI `praxo-core==0.9.0` | `cd language/python/examples/live-model; python -m venv .venv; .venv/bin/python -m pip install -r requirements.txt; .venv/bin/python live_starter.py` |
| TypeScript | npm `@axisvela/praxo-core@0.8.0` | `cd language/typescript/examples/live-model; npm install; npm start` |
| Java | Maven `com.axisvela:praxo-core:0.9.0` | `cd language/java/examples/live-model; mvn -q compile exec:java` |
| C# | NuGet `Praxo.Core==0.9.1` | `cd language/csharp/examples/live-model; dotnet run` |
| Rust | crates.io `praxo-core==0.9.1` with `http-ureq` | `cd language/rust/examples/live-model; cargo run` |
| R | r-universe `praxocore==0.10.1` | `cd language/r/examples/live-model; Rscript live.R` |
| Ruby | source | `ruby -I language/ruby/lib language/ruby/examples/live-model/live_starter.rb` |
| PHP | source | `php language/php/examples/live-model/live_starter.php` |
| Elixir | source | `elixir -pa language/elixir/build/ebin language/elixir/examples/live-model/live_starter.exs` |
| Lua | source | `lua language/lua/examples/live-model/live_starter.lua` |

Go、Python、TypeScript、Java、C# 和 R 示例导入已发布包。Rust、Ruby、PHP、Elixir
和 Lua 示例使用仓库源码，以便使用当前 adapter 代码；其 README 也记录可用的包安装
方式。Rust 示例使用可选 `http-ureq` 特性，不依赖已发布 crate 中的该特性。

Python `0.7.0`、TypeScript `0.6.0` 和 Java `0.9.0` 已包含 OpenAI tool-wire
修复，可正确处理工具结果回传。

## 示例内容

- 从环境变量配置模型 Adapter；
- 通过对应语言 Core 注册工具；
- 允许列表只包含 `get_time`；
- Policy hook 拒绝其他所有工具；
- 运行一次正常 Agent 并输出模型结果。

## 拒绝检查

真实模型路径不能假设模型一定会请求危险工具。请运行对应消费者 Starter，
验证确定性 allow/deny，并确认拒绝调用不产生工具副作用：

- [Go 消费者](consumer-go.md)
- [Python 消费者](consumer-python.md)
- [TypeScript 消费者](consumer-typescript.md)
- [Java 消费者](consumer-java.md)
- [C# starter](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/consumer)
- [Rust starter](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/consumer)
- [R starter](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/consumer)
- [Ruby starter](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/consumer)
- [PHP starter](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/consumer)
- [Elixir starter](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/consumer)
- [Lua starter](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/consumer)

## 排错

| 现象 | 检查 | 修复 |
| --- | --- | --- |
| 连接被拒绝或 DNS 失败 | `PRAXO_BASE_URL` | 使用完整 API 根地址，通常以 `/v1` 结尾。Ollama 使用 `http://localhost:11434/v1`；不要指向网页 UI 或模型下载地址。 |
| 404 或找不到端点 | Base URL 路径 | 托管 Provider 通常要求 `/v1`；避免出现 `/v1/v1`。核对 Provider 的兼容端点。 |
| 托管端点返回 401/403 | `PRAXO_API_KEY` | 设置有效 Key，且不要提交到仓库。Ollama 通常不需要 Key；部分网关还要求额外 Header 或 Bearer Token。 |
| 模型不存在或 400 模型错误 | `PRAXO_MODEL` | 使用端点实际提供的模型 ID，不是包名或展示名；先拉取 Ollama 模型。 |
| 请求挂起 | 端点、网络、模型大小 | 换更小的模型，检查代理/防火墙，并在示例代码中增加 Adapter 超时。live 示例没有独立超时环境变量。 |
| 模型没有调用工具 | Prompt 与模型能力 | 明确要求使用 `get_time` 并传入 `zone`；小模型可能忽略工具或编造参数。 |
| Tool Schema 或参数错误 | `zone` 参数 | 使用字符串时区，如 `UTC` 或 `Europe/Berlin`；不要传数字或空对象。 |
| Policy 拒绝 | 工具范围 | live 示例只允许 `get_time`；其他工具被拒绝是预期行为，用消费者 Starter 验证拒绝路径。 |
| PowerShell 找不到命令 | 环境变量或引用 | 设置 `$env:PRAXO_BASE_URL`、`$env:PRAXO_MODEL`；Go 运行时设置 `$env:GOWORK = "off"`。 |
| Windows 路径或构建错误 | 工具链与路径 | 从仓库根目录或文档指定的示例目录运行；含空格路径要加引号。C、C++、Zig 可能需要文档中的编译器或 SDK。 |

语言示例使用 Adapter 默认 HTTP 超时。本地模型较慢时，在示例代码中增加超时；不要
添加未文档化的环境变量。

常用环境变量：

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
export PRAXO_API_KEY=...   # 仅托管端点
```

PowerShell：

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "llama3.2"
$env:PRAXO_API_KEY = "..."
```

报告问题时记录端点类别、模型 ID、包版本、命令和实际错误；不要粘贴 Key 或租户数据。

该示例是集成起点，不是生产安全 Profile。身份、持久审批、隔离和效果对账仍由
应用负责。
