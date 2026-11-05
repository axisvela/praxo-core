# 绑定已验证身份与策略

本配方展示应用层如何使用已验证 principal 进行 Core 授权。Core 提供授权 Hook 与最终操作
复查；应用必须认证调用方、绑定租户与资源，并 fail closed。

它不是身份提供商、策略决策服务、持久审批库或 exactly-once 效果机制。

## 模式

1. **在 Core 之外认证。** 通过身份系统验证调用方，生成包含 actor ID、租户、角色和
   过期时间的 principal。
2. **上下文中只放已验证数据。** 绝不从模型输出或工具参数读取 actor ID/角色。
3. **在 Hook 中授权。** 拒绝缺失、过期或畸形 principal；检查角色、租户、资源、工具名
   与参数。
4. **复查最终操作。** Middleware 或审批编辑可能改变工具名/参数；Core 会对最终值再次授权。
5. **Fail closed。** 必需身份或策略基础设施不可用时返回错误，不得放行执行。

## 受测示例

可运行示例是独立的 L4 配方模块
[`examples/recipes/identity-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/identity-go)。
在该目录运行：

```sh
GOWORK=off go test -mod=readonly -run Identity -v ./...
```

| 检查 | 预期结果 |
| --- | --- |
| 缺少已验证 principal | 拒绝；工具零副作用 |
| principal 已过期 | 拒绝；工具零副作用 |
| 租户不匹配 | 拒绝；工具零副作用 |
| 模型声称 admin 角色 | 忽略；拒绝；工具零副作用 |
| 匹配租户的有效 operator | 允许一次 |

配方在认证后把 principal 放入 context value。真实服务中，该值必须来自已验证请求上下文或
身份中间件，而不是 prompt 或模型。

## 重要限制

- 工具参数中的角色字符串是不可信输入。Hook 必须使用已验证 principal。
- 身份授权不替代沙箱、最小权限凭据、网络控制或实时安全。
- 审批决定不是持久审批库；绑定、过期、撤销和审计需由应用定义。
- 工具调用成功不证明外部效果已提交。高影响操作需要效果账本或对账。

参见[安全模型](../security/index.md)、[受治理执行设计](../reference/governed-execution.md)
与[采用指南](../getting-started/adoption.md)。
