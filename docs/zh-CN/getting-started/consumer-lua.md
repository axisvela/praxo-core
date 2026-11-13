# Lua 独立消费者

在自己的应用中使用已发布的 LuaRocks `praxo-core` `0.6.0-1`，要求 Lua 5.4。
无需检出 PRAXO-CORE 源码、API Key、模型服务或 AxisVela 产品。安装需要 LuaRocks
访问或已有 rock 缓存。

这是扩展语言 starter，只演示 allow/deny 路径，不在四个具备治理负向矩阵的试点语言范围内。

## 选择边界

适用于需要显式工具范围和 Policy 的嵌入式模型/工具循环。应用仍负责模型访问、真实身份、
持久审批、外部效果和隔离。它不是托管 Agent 平台、持久图引擎或沙箱服务。
选型前阅读[何时不应选择 Core](when-not-to-use.md)。

## 在新应用安装

```sh
luarocks install praxo-core 0.6.0-1
```

验收时不要把仓库的 `language/lua` 目录加入 `package.path`，也不要使用本地 rockspec
或源码检出。starter 里保留源码回退路径，只是为了让本仓库无需 LuaRocks 也能运行同一文件；
真实消费者应安装 rock。

## 应用源码

以下为 `starter.lua`，来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/language/lua/examples/consumer/starter.lua)。

<!-- lua-consumer-source: starter.lua -->

## 验收测试

以下为 `test_starter.lua`，来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/language/lua/examples/consumer/test_starter.lua)。

<!-- lua-consumer-source: test_starter.lua -->

## 验证

```sh
luarocks install praxo-core 0.6.0-1
lua test_starter.lua
```

程序预期输出：

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

模型是确定性 fixture，不是真实 LLM。`allowed_tools` 限制工具名，Policy 额外检查目标
参数。被拒绝的 private 目标抛出 `AGENT_POLICY_DENIED`，且不得增加内存计数器。
替换为真实适配器后仍需保留这些测试。

## 范围

本 starter 仅证明指定 rock 与 fixture 行为，不包含治理负向矩阵，也不证明真实身份、
持久审批、效果对账或隔离。后续参考 [Lua 实现指南](../languages/lua/index.md)及
[安全模型](../security/index.md)。
