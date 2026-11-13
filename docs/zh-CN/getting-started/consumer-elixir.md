# Elixir 独立消费者

在自己的应用中使用已发布的 Hex `praxo_core` `0.8.0`，要求 Elixir 1.14 或更新版本。
无需检出 PRAXO-CORE 源码、API Key、模型服务或 AxisVela 产品。安装需要 Hex 访问或
已有包缓存。

这是扩展语言 starter，只演示 allow/deny 路径，不在四个具备治理负向矩阵的试点语言范围内。

## 选择边界

适用于需要显式工具范围和 Policy 的嵌入式模型/工具循环。应用仍负责模型访问、真实身份、
持久审批、外部效果和隔离。它不是托管 Agent 平台、持久图引擎或沙箱服务。
选型前阅读[何时不应选择 Core](when-not-to-use.md)。

## 创建应用

在 `mix.exs` 中声明精确依赖：

```elixir
defp deps do
  [
    {:praxo_core, "~> 0.8.0"}
  ]
end
```

然后运行 `mix deps.get`。验收时不要使用 `path:` 依赖或语言源码目录的检出。

## 应用源码

以下为 `starter.exs`，来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-elixir/starter.exs)。

<!-- elixir-consumer-source: starter.exs -->

## 验收测试

以下为 `test_starter.exs`，来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-elixir/test_starter.exs)。

<!-- elixir-consumer-source: test_starter.exs -->

## 验证

```sh
mix deps.get
mix run test_starter.exs
```

程序预期输出：

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

模型是确定性 fixture，不是真实 LLM。`allowed_tools` 限制工具名，Policy 额外检查目标
参数。被拒绝的 private 目标返回 `AGENT_POLICY_DENIED`，且不得增加内存计数器。
替换为真实适配器后仍需保留这些测试。

若使用无 Hex 的源码检出，可先编译 beams，再用
`elixir -pa language/elixir/build/ebin test_starter.exs` 运行；该路径不算独立消费者证据。

## 范围

本 starter 仅证明指定 Hex 包与 fixture 行为，不包含治理负向矩阵，也不证明真实身份、
持久审批、效果对账或隔离。后续参考 [Elixir 实现指南](../languages/elixir/index.md)及
[安全模型](../security/index.md)。
