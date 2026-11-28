# Go Core

Go 是参考实现。安装当前 Core 版本：

```bash
go get github.com/axisvela/praxo-core/v2@v2.11.3
```

模块声明 Go 1.25；CI 和发布使用 Go 1.26.11。连接 Ollama 或 OpenAI-compatible
端点的可运行示例见[快速开始](../../getting-started/quickstart.md)。

## 功能与边界

参考实现包含受治理的 agent 循环、Policy、Tool、Memory、Event、Checkpoint、
Middleware、Delegation 和 VFS 契约。具体 Provider 和产品控制面属于可选集成，
不是必需依赖。参见[基础能力](../../reference/primitives.md)、
[安全](../../security/index.md)和[适配器范围](../../integrations/index.md)。

## API 与示例

- [Go API 参考](https://pkg.go.dev/github.com/axisvela/praxo-core/v2)
- [快速开始源码](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/quickstart)
- [Checkpoint 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/checkpoint)
- [受治理 Workspace 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/governed-workspace)
- [兼容性](../../project/compatibility.md)

## 从源码验证

在仓库根目录运行，并设置 `GOWORK=off`：

```bash
go test ./...
go vet ./...
go build ./...
```
