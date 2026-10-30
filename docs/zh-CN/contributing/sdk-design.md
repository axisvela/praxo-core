# Core 契约与设计

Go 是参考实现，[`spec/`](https://github.com/axisvela/praxo-core/tree/main/spec)
是规范契约。各 Core 提供符合语言习惯的 API，但不能改变 wire 名称或声明的行为。
规范与参考实现不一致属于缺陷，不应静默分叉。

| 层次 | 要求 |
| --- | --- |
| Wire | 保留字段名称、大小写、事件类型、错误码和消息封装 |
| 行为 | 通过声明范围内的共享向量 |
| API | 将接口和选项映射为符合语言习惯的形式 |
| 一致性 | 执行向量、parity、API 检查和语言专项测试 |

保留 `image_url`、`runId`、`plugin_id` 等混合命名，不能为了本地风格统一改名。
相关定义见[事件参考](../reference/events.md)、wire 工件和各语言 parity 清单。

## 语言目录结构

不要把 Go 的 `pkg/` 目录树复制到每种语言。应使用符合该语言和包管理器习惯的结构，同时保持契约边界清晰。

Core 实现应提供：

- 源码树，核心模块清晰，不包含产品专用代码；
- `README.md`、`LICENSE` 和安装/构建说明；
- `api/` 快照或等价的 API 检查；
- 基于 `spec/vectors` 的 conformance runner；
- 语言测试，包括负向和安全敏感路径；
- 可选 `adapters/` 目录，用于该语言的 provider 适配器。

将契约区域映射到本地模块，并在 parity 清单中记录映射。名称接近有帮助，但不要求物理上照搬 `pkg/...`，也不能为了结构一致写出不符合语言习惯的代码。

## 适配器

适配器是可选的。Core 不能导入自己的适配器，适配器也不能成为一致性测试的前置条件。

- 语言本地适配器放在 `language/<language>/adapters/<provider>`；依赖较重时使用独立版本的模块。
- provider SDK、凭据、端点和租户策略不能进入 Core。
- 适配器测试与 Core 向量分开；Core conformance 通过不代表 live provider 已验证。
- 不要镜像 Go 根目录的 `adapters/`，也不要为每种语言实现全部 Go 适配器。新增适配器必须有消费者、维护者、许可证审查和测试。
- 适配器的源码标签不代表包注册表发布或 live provider 验证。

## 变更流程

1. 检查参考行为与规范工件。
2. 契约变更同步更新 wire 定义和向量。
3. 更新对应 parity 清单。
4. 使用 Go 参考实现验证向量。
5. 完成 Core 实现，执行一致性和 API 检查。
6. 记录支持范围、版本兼容性和限制。

不能仅为 Core 扩大 Go `pkg/...` API。具体适配器是可选能力，不代表所有语言都有。

## 兼容与安全

`spec/SPEC_VERSION` 与 Core 独立版本化。wire 字段、事件、流类型、插件消息或错误码
变更必须更新规范，并按对各 Core 的破坏性影响评估。参见
[兼容政策](../project/compatibility-policy.md)、[API 稳定性](../project/api-stability.md)。

共享契约不保证所有 Core 都有 Go 的全部功能，请查看[支持政策](../languages/support.md)
与语言 API。Core 保持 MIT，依赖需要兼容许可，凭据与租户数据由调用方配置。
安全敏感行为必须逐语言验证。实现类型与门禁见[语言支持规范](language-policy.md)。
