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
| Go | `github.com/axisvela/praxo-core/v2@v2.8.0` | `cd language/go/examples/live-model/go; go run .` |
| Python | PyPI `praxo-core==0.9.0` | `cd language/python/examples/live-model; python -m venv .venv; .venv/bin/python -m pip install -r requirements.txt; .venv/bin/python live_starter.py` |
| TypeScript | npm `@axisvela/praxo-core@0.7.1` | `cd language/typescript/examples/live-model; npm install; npm start` |
| Java | Maven `com.axisvela:praxo-core:0.9.0` | `cd language/java/examples/live-model; mvn -q compile exec:java` |
| C# | NuGet `Praxo.Core==0.9.0` | `cd language/csharp/examples/live-model; dotnet run` |
| Rust | crates.io `praxo-core==0.9.0` with `http-ureq` | `cd language/rust/examples/live-model; cargo run` |
| R | r-universe `praxocore==0.10.0` | `cd language/r/examples/live-model; Rscript live.R` |
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

- **连接被拒绝：** 确认 `PRAXO_BASE_URL` 是否包含端点要求的 `/v1`。
- **模型不存在：** 检查 `PRAXO_MODEL` 与端点实际提供的模型名。
- **认证失败：** 托管端点需要设置 `PRAXO_API_KEY`。
- **没有工具调用：** 明确要求模型使用 `get_time`；部分小模型会直接回答而不调用工具。
- **超时：** 使用更小的模型，或调整对应语言示例中的 Adapter 超时。

该示例是集成起点，不是生产安全 Profile。身份、持久审批、隔离和效果对账仍由
应用负责。
