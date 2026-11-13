# 将 Core 嵌入 HTTP 服务

本教程使用可运行的
[`examples/embedded-service`](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service)
项目，展示厂商中立服务的最小形态：调用方上下文通过 HTTP 进入，应用选择租户，
Core 执行 Agent，服务返回结构化输出。

## 运行

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2

cd examples/embedded-service
go run . -addr :8080 -tenant local
```

调用服务：

```bash
curl -s http://localhost:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

## Python 变体

Python 示例使用相同的调用方上下文边界和标准库 HTTP Server：

```bash
cd language/python/examples/service
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python service.py
```

```bash
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

确定性测试：

```bash
.venv/bin/python -m unittest test_service.py -v
```

## 已验证身份变体

[认证服务示例](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth)
增加应用侧 HMAC Bearer Token、subject/tenant claims、过期检查和 Agent 运行前的
租户允许列表。

```bash
cd examples/embedded-service-auth
go test ./...
```

这是应用局部 Token 格式，不是通用 JWT 实现。生产服务应使用自己的身份提供商、
密钥管理、audience 校验和撤销机制。

## 请求流程

1. HTTP Handler 检查 `X-Praxo-Principal` 是否存在。
2. 应用选择租户，并将 principal 和 tenant 传入 Core Session。
3. Agent 在显式超时下调用模型。
4. Policy 只允许模型生成和 `get_time` 工具。
5. Handler 返回包含模型输出的 JSON。

`X-Praxo-Principal` 只是上下文占位，不是认证。生产服务必须验证调用方，并从可信
应用状态中推导 principal 和 tenant。

## 服务边界

示例包含：

- `/healthz` 健康检查；
- 有大小限制的 `POST /run` JSON 请求；
- HTTP 读、写和空闲超时；
- 模型 HTTP 超时；
- SIGINT/SIGTERM 有界优雅退出；
- 由应用拥有的事件日志。

它有意不包含持久 Session、Checkpoint、审批或租户存储。这些属于应用或产品职责。

## 无需模型的测试

```bash
cd examples/embedded-service
go test ./...
```

测试使用 fake model 和 `httptest`，不需要真实端点。

## 下一步

- 用已认证身份替换 principal Header。
- 按租户隔离 Checkpoint、事件和工具访问。
- 为长时工作增加持久 Checkpoint 存储。
- 将 Shell、文件和网络工具置于应用拥有的隔离之后。
- 上线前使用[应用嵌入清单](application-integration-checklist.md)。

## 相关文档

- [应用嵌入清单](application-integration-checklist.md)
- [身份与策略](identity-policy.md)
- [长时操作](long-running-operations.md)
- [安全模型](../security/index.md)
- [示例目录](../getting-started/examples.md)
