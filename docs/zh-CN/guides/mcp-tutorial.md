# 多语言 MCP 客户端

本教程将已发布 Core 包连接到本地 MCP Server，列出工具、注册到 Core Registry，
并调用一个工具。

可运行示例：

- [Python stdio](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/mcp)
- [TypeScript stdio](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/mcp)
- [C# 进程内 transport](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/mcp)

每个示例都使用本地确定性 Server，不需要外部 MCP 服务。

## Python

```bash
cd language/python/examples/mcp
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python client.py
.venv/bin/python -m unittest test_client.py -v
```

预期输出：

```text
tools=add,echo; sum=5
```

## TypeScript

```bash
cd language/typescript/examples/mcp
npm install
npm start
npm test
```

## C#

```bash
cd language/csharp/examples/mcp
dotnet run
dotnet run -- --test
```

## 流程

1. 启动或连接 MCP Transport。
2. 初始化会话。
3. 分页列出工具，拒绝重复名称。
4. 将选定工具注册到 Core Registry。
5. 每个工具调用到达 Server 前都必须经过授权。
6. 调用工具，并将结果视为不可信输入。

C# 示例使用进程内 transport。真实 stdio Server 使用 `McpServerOptions` 和
`new McpClient(options)`，客户端流程相同。

## 边界

- MCP 是工具会话，不是模型 Provider。
- 认证属于 Transport 或 Server 会话。
- 工具输出是不可信内容。
- 本地取消不证明远端工作已停止。
- 示例不提供托管 MCP 服务、Schema 晋级或生产隔离。

## 相关文档

- [Provider 与 MCP 演练](provider-walkthrough.md)
- [示例目录](../getting-started/examples.md)
- [MCP 客户端参考](../reference/mcp-client.md)
- [Adapter 状态](../languages/adapter-status.md#mcp)
- [应用嵌入清单](application-integration-checklist.md)
