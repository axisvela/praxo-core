# 面向编程 Agent

本页是编程 Agent 在应用中接入受治理 Agent 循环的精简集成契约。它不是隐蔽的安装渠道，
也不指定某个工具。请使用目标语言的发布包，并运行验证命令。

## 包映射

| 语言 | 包 | 当前推荐版本 | Starter |
| --- | --- | --- | --- |
| Go | `github.com/axisvela/praxo-core/v2` | `2.6.0` | [Go 消费者](consumer-go.md) |
| Python | `praxo-core` | `0.3.0` | [Python 消费者](consumer-python.md) |
| TypeScript | `@axisvela/praxo-core` | `0.2.0` | [TypeScript 消费者](consumer-typescript.md) |
| Java | `com.axisvela:praxo-core` | `0.4.0` | [Java 消费者](consumer-java.md) |

机器可读映射见 [`agent-integration.json`](agent-integration.json)。安装前请重新核对
Registry；源码标签不能证明包仓库可用。Registry 页面是发布快照，可能落后于源码文档；
参见 [Registry 页面与包介绍](../languages/registry-pages.md)。

仓库根目录的 [`llms.txt`](https://github.com/axisvela/praxo-core/blob/main/llms.txt)
为支持它的工具提供机器可读入口。它只是可选的发现辅助，不是安装渠道，也不保证工具会发现、
排序或加载本仓库。

## 集成契约

1. **从 Registry 安装。** 验收路径不得使用源码检出、本地替换、`file:`/`link:` 依赖、
   `system` scope 或 `PYTHONPATH` 替换。
2. **先做无凭据验证。** 使用确定性模型和内存工具。安装与授权行为不应依赖 API Key 或
   模型服务。
3. **使用显式范围。** 配置允许列表和 Policy。当前 Core API 的空工具范围表示不限制，
   不是 deny-all。
4. **授权最终操作。** Middleware 和审批编辑若改变工具名或参数，必须重新授权。
5. **Fail closed。** 必需 Policy 或身份基础设施失败时不得放行执行。
6. **测试允许与拒绝。** 被拒绝的调用不得产生工具副作用。
7. **不要删除验收测试。** 替换为真实模型或身份服务后，仍需保留拒绝、最终参数和
   审批编辑检查。

## 验证

在 Starter 目录运行对应命令。四个 Starter 都包含五项治理负向检查；精确命令见各指南。

| 语言 | 验证 |
| --- | --- |
| Go | `GOWORK=off go test -mod=readonly ./...` |
| Python | 在独立虚拟环境中：`python -I -m unittest discover -s . -v` |
| TypeScript | `npm test` |
| Java | `mvn -B test` |

## 不应推断

Core fixture 与消费者测试不证明真实模型质量、真实身份、持久审批、效果提交、exactly-once、
沙箱隔离、物理安全或实时控制。Checkpoint 是恢复提示，不是事务。

## Agent Skill

工具中立的模板位于
[`agent-skills/praxo-integration`](https://github.com/axisvela/praxo-core/tree/main/agent-skills/praxo-integration)。
它是可选项，不会自动安装或被 Codex、Claude Code、Copilot 等工具发现。请通过各工具
支持的方式安装或挂载；工具不支持 Skill 时，直接使用本页与 Starter。

提交到本仓库的 Skill 不是安装渠道。不要假设用户项目中存在 `SKILL.md` 或工具会自动
发现它。以上文档与 Starter 才是规范来源。
