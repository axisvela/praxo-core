# 构建只读 Workspace Agent

本教程从[真实模型 Golden Path](../getting-started/live-model-golden-path.md)
继续，构建一个可检查目录但不能修改文件的本地 Agent。

可运行项目位于
[`examples/workspace-agent`](https://github.com/axisvela/praxo-core/tree/main/examples/workspace-agent)。
它使用已发布的 `github.com/axisvela/praxo-core/v2` 模块，不使用仓库替换。

## 前置条件

- Go 1.26.11 或更新版本。
- 本地 Ollama，或其他 OpenAI-compatible 端点。
- 一个小模型，例如 `llama3.2`。

## 运行示例

在仓库根目录执行：

```bash
mkdir -p workspace
printf 'Quarterly status: all checks green.\n' > workspace/report.txt

export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2

cd examples/workspace-agent
go run . --workspace workspace
```

默认提示会要求 Agent 列出 Workspace、读取文本文件并总结。

## 示例连接了哪些能力

- `localfs.New` 将文件访问根定在 Workspace 目录。
- `vfstools.Tools` 注册 `fs.list`、`fs.read`、`fs.glob` 和 `fs.grep`。
- `agent.Options.AllowedTools` 限制暴露的工具。
- Policy hook 只允许模型生成和四个读取工具。
- Policy 路径检查拒绝绝对路径和 `..` 逃逸。
- `event.FuncSink` 将生命周期事件输出到 stderr。

允许列表和 Policy 都由应用拥有。Core 执行决策，不推断生产授权策略。

## 验证边界

要求 Agent 创建文件：

```bash
go run . --workspace workspace --prompt "Create notes.md with a summary."
```

`fs.write` 不在允许列表中，Policy 会拒绝，因此不应创建 `notes.md`。

这与 [governed workspace 示例](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace)
使用相同的分离方式：读取可用，写入需要应用显式决策，并且在该示例中需要人工审批。

## 走向真实应用

- 将本地 Workspace 替换为应用的存储或 Sandbox 接缝。
- 提供已认证 principal 和租户感知 Policy。
- 为长时或有副作用工作增加 Checkpoint。
- 将事件转发到可观测性流水线。
- 只有在工具范围和信任边界明确后才增加 MCP 工具。
- 凭据、持久审批和效果对账保留在 Core 之外。

## 相关文档

- [示例目录](../getting-started/examples.md)
- [真实模型 Golden Path](../getting-started/live-model-golden-path.md)
- [身份与策略配方](identity-policy.md)
- [接入示例](recipes.md)
- [隔离](../security/containment.md)
