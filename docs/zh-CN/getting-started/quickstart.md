# 快速开始

先通过[Go 独立消费者](consumer-go.md)在自己的应用中安装发布包，验证允许与拒绝路径，
无需检出源码、API Key 或模型服务。

Python 使用[独立消费者指南](consumer-python.md)，通过 PyPI 发布包与隔离环境完成验收。
TypeScript 使用[独立消费者指南](consumer-typescript.md)，通过 npm 发布包、固定锁文件与
Node.js 20 或更新版本完成验收。
Java 使用[独立消费者指南](consumer-java.md)，通过 Maven Central 发布产物与 Java 21
或更新版本完成验收。

以下端点示例连接 OpenAI 兼容服务，需要检出 PRAXO-CORE 源码，并从仓库根目录运行命令。
无需提供商 SDK。示例的宽松策略不是生产授权配置。

## 前置条件

- Go 1.26.10（CI/发布验证版本，请使用完整安装的工具链）
- 一个 OpenAI 兼容端点：
  - 本地 Ollama，或
  - 托管的 OpenAI 兼容 API

## 使用 Ollama 运行

```bash
ollama pull llama3.2
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
GOWORK=off go run ./examples/quickstart
```

## 使用托管端点运行

```bash
export PRAXO_BASE_URL=https://api.openai.com/v1
export PRAXO_API_KEY=...
export PRAXO_MODEL=gpt-4o-mini
GOWORK=off go run ./examples/quickstart
```

PowerShell 使用 `$env:PRAXO_BASE_URL = "..."`，变量名相同。可通过
`PRAXO_PROMPT` 修改请求内容。

## 示例内容

- 仅使用标准库的模型适配器
- 通过 `tool.Registry` 暴露的 `get_time` 工具
- 通过 `agent.Options.OnDelta` 流式输出文本增量
- 通过 `event.Sink` 传递事件（写入 stderr）
- 通过 `policy.Hook` 执行策略授权
- 受治理的 Agent 循环

## 下一步

- [OpenAI 兼容适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat)
- [MCP 工具网关](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp)
- [Reference workspace Agent](https://github.com/axisvela/praxo-core/tree/main/examples/reference)
- [AxisVela 生态集成](../integrations/ecosystem.md)
- [与其他 Go Agent 框架的对比](../project/comparison.md)
- [插件编写](../guides/plugins.md)
