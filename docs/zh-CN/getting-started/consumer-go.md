# Go 独立消费者

在自己的新应用中使用已发布的 Core `2.7.0`，不需要检出 PRAXO-CORE 源码。
Starter 使用确定性模型和内存工具，无需凭据、模型服务或 AxisVela 产品，便能验证安装与授权行为。

## 是否适用？

| 任务 | 适用性与边界 |
| --- | --- |
| 在现有 Go 应用嵌入模型与工具循环 | 适用；应用负责模型适配器与工具 |
| 授权工具调用并验证拒绝路径 | 适用；应用提供策略与真实身份 |
| 接入人工审批或 Checkpoint 恢复 | 提供接口；持久审批和外部效果对账仍属集成职责 |
| 持久图工作流或 exactly-once 效果 | Core 单独不提供；需要专门运行时或执行服务 |
| 托管沙箱或机器人安全控制器 | 不提供；Core 提供集成边界，而非这些服务 |

选型前阅读[何时不应选择 Core](when-not-to-use.md)。

## 创建应用

使用 Go `1.26.11`，即 CI/发布验证工具链。安装需要访问 Registry 或使用已有模块缓存。
全部命令应先设置 `GOWORK=off`，避免父目录工作区替换为本地依赖。
PowerShell 使用 `$env:GOWORK = "off"`，POSIX Shell 使用 `export GOWORK=off`。

在新的应用目录运行：

```sh
go mod init example.com/praxo-starter
go get github.com/axisvela/praxo-core/v2@v2.7.0
```

## 应用源码

以下为 `main.go`。文档站直接从[受测 Starter 源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-go/main.go)
渲染，不另外维护代码副本。在 GitHub 阅读时可通过该链接查看完整源码。

<!-- go-consumer-source: main.go -->

## 验收测试

以下为 `main_test.go`，同样从[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-go/main_test.go)
渲染。依赖检查拒绝模块替换，并验证精确 Core 版本。

<!-- go-consumer-source: main_test.go -->

## 验证

添加两个文件后，解析依赖并验证应用：

```sh
go mod tidy
go test -mod=readonly ./...
go vet -mod=readonly ./...
go build -mod=readonly ./...
go run -mod=readonly .
```

程序预期输出：

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

Fake Model 不依赖策略结果，始终请求工具。显式 `AllowedTools` 限制工具名，Policy
额外限制目标参数。private 目标被拒绝后，不得增加效果计数。当前 API 的空 allowlist
不代表 deny-all。

## 治理验收

### 发布包升级

在源码检出目录运行 `python scripts/test_go_upgrade.py -v`，会创建一个全新消费者，先安装
`tests/consumer/go.mod` 固定的历史版本，再在同一应用中升级到包映射里的 Go 推荐版本。
测试拒绝模块替换、核对两个精确版本，并要求应用源码不变。历史阶段只检查基础允许/拒绝；
升级后运行五项治理负向检查、build、vet 和预期程序输出，不声称历史安全基线也通过更强检查。

CI 在 Linux、Windows、macOS 执行该检查。每次运行只证明该发布版本对和 fixture，不证明
未发布候选版本、任意版本升级、真实用户采用或生产留存。

### 负向检查

发布包测试还包含五项负向检查：

```sh
go test -mod=readonly -run Governed -v ./...
```

| 检查 | 必须结果 |
| --- | --- |
| 缺少必需 Policy | 应用守卫在运行前拒绝；工具零副作用 |
| 工具范围为空 | 应用守卫拒绝；工具零副作用 |
| Middleware 改变最终参数 | 最终操作重新授权；拒绝阻止副作用 |
| 审批编辑改变参数 | 编辑后的操作重新授权；拒绝阻止副作用 |
| Policy 服务错误 | 运行 fail closed；工具零副作用 |

测试位于[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-go/governed_test.go)。
守卫属于应用层：Core 保留普通 nil-policy 嵌入模式。这些检查不证明真实身份、持久审批、
效果对账或通用安全 Profile。

这些检查只证明该发布包 fixture，不证明真实模型质量、身份真实性、进程隔离、持久效果
或生产安全。连接真实模型请继续阅读[端点快速开始](quickstart.md)与[采用指南](adoption.md)，
替换 Fake Model 后仍需保留拒绝测试。
