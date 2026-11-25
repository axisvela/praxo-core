# 代表性端到端链路教程

本教程用真实本地模型运行一条完整的受治理链路：

```text
Ollama 模型
  -> MCP record 工具
  -> 最终参数授权
  -> 受治理子代理委派
  -> OTel span 与 Harmovela 事件
  -> 编辑参数后拒绝，零效果
```

可运行项目位于
[`language/go/examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/representative-chain)。
它使用 Go module `github.com/axisvela/praxo-core/v2@v2.9.0`、进程内 MCP server、
loopback Harmovela sink 和本地 Ollama endpoint。

## 前置条件

- Go 1.25 或更新版本
- Ollama 运行在 `http://127.0.0.1:11434`
- 支持工具调用的 Ollama 模型；本教程使用 `qwen3.5:4b`

```bash
ollama pull qwen3.5:4b
```

运行前确认 endpoint：

```bash
curl http://127.0.0.1:11434/api/tags
```

## 运行

```bash
cd language/go/examples/representative-chain
export PRAXO_OLLAMA_MODEL=qwen3.5:4b
go run .
```

PowerShell：

```powershell
cd examples\representative-chain
$env:PRAXO_OLLAMA_MODEL = "qwen3.5:4b"
go run .
```

默认 endpoint 为 `http://127.0.0.1:11434/v1`。其他 OpenAI 兼容 endpoint 可设置
`PRAXO_OLLAMA_BASE_URL`，需要密钥时设置 `PRAXO_OLLAMA_API_KEY`。

2026-11-17 记录的输出：

```text
output: DONE
effects: map[child:1 parent:1]
child calls: 2
spans: 10
events: 10
denied effects: 0
```

## 运行断言

```bash
PRAXO_OLLAMA_MODEL=qwen3.5:4b go test -v ./...
```

预期：

```text
--- PASS: TestRepresentativeChain
--- PASS: TestDenialZeroEffect
```

未设置 `PRAXO_OLLAMA_MODEL` 时测试自动跳过。拒绝测试不需要模型，用于确认中间件
编辑后重新授权、MCP 工具未执行且效果计数保持为零。

## 每一步证明什么

| 步骤 | 证据 |
| --- | --- |
| 真实模型 | 父代理使用 OpenAI 兼容 Ollama endpoint，而不是 fixture |
| MCP 工具 | 模型调用 MCP `record` 工具，`target=parent` |
| 最终授权 | 父策略授权工具名和最终参数 |
| 委派 | 父代理调用应用级 `delegate` 工具；子作用域仅含 `record`，父子策略组合 |
| OTel | 内存 exporter 收到 `praxo.run.started`、`praxo.tool.call` 和 `praxo.run.completed` span |
| Harmovela | loopback HTTP sink 收到相同生命周期事件 |
| 拒绝 | 中间件把 `target` 改为 `blocked`，重新授权拒绝，MCP 工具未调用 |

## 排错

| 现象 | 检查 |
| --- | --- |
| `connection refused` | 启动 Ollama，并确认 `http://127.0.0.1:11434/api/tags` 可访问 |
| `model not found` | 拉取准确模型 ID 并设置 `PRAXO_OLLAMA_MODEL` |
| 模型未调用工具 | 使用支持工具调用的模型，并保留示例中的明确提示词 |
| Go 对 `v2.9.0` 报 checksum mismatch | 清理陈旧的 module cache 条目后重新下载；不要手动修改 `go.sum` |
| Harmovela 或 OTel 断言失败 | 检查事件 sink 连接；不需要外部 collector |

清理陈旧 Go module cache 条目，但不要绕过 module 认证：

```bash
go clean -modcache
```

## 边界

这是本地集成证据，不是生产部署。它使用一个本地模型、平台、进程内 MCP 传输和
loopback Harmovela server；子代理模型为确定性 fixture。它不证明远程 MCP 或
Harmovela、独立复现、吞吐、故障恢复、exactly-once 或通用 prompt-injection 防护。

其余 Core SDK 语言的确定性对应链路位于各自的 representative-chain 示例或原生
测试套件，覆盖相同的 MCP、授权、委派、OTel/Harmovela 和拒绝边界，但不需要真实
provider；记录范围和限制见[验证证据](../project/verification-evidence.md)。

更多证据和委派边界见[验证证据](../project/verification-evidence.md)和
[多 Agent 模式](multi-agent.md)。
