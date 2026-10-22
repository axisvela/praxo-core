# 快速开始

本快速开始使用 OpenAI 兼容端点运行一个受治理 Agent。无需提供商 SDK。

## 前置条件

- Go 1.26 或更高版本
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
- 通过 `event.Sink` 传递事件
- 通过 `policy.Hook` 执行策略授权
- 受治理的 Agent 循环

## 下一步

- [OpenAI 兼容适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat)
- [MCP 工具网关](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp)
- [Reference workspace Agent](https://github.com/axisvela/praxo-core/tree/main/examples/reference)
- [AxisVela 生态集成](12-ecosystem.md)
- [与其他 Go Agent 框架的对比](comparison.md)
- [插件编写](10-plugin-authoring.md)
