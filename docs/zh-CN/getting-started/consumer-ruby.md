# Ruby 独立消费者

在自己的应用中使用已发布的 `praxo-core==0.7.0`，要求 Ruby 3.1 或更新版本。
无需检出 PRAXO-CORE 源码、API Key、模型服务或 AxisVela 产品。安装需要 RubyGems
访问或已有 gem 缓存。

这是扩展语言 starter，只演示 allow/deny 路径，不在四个具备治理负向矩阵的试点语言范围内。

## 选择边界

适用于需要显式工具范围和 Policy 的嵌入式模型/工具循环。应用仍负责模型访问、真实身份、
持久审批、外部效果和隔离。它不是托管 Agent 平台、持久图引擎或沙箱服务。
选型前阅读[何时不应选择 Core](when-not-to-use.md)。

## 创建应用

在 `Gemfile` 中声明精确依赖：

```ruby
source 'https://rubygems.org'

gem 'praxo-core', '0.7.0'
```

然后运行 `bundle install`。不要使用 `path:`、`git:`、vendored 检出或 `$LOAD_PATH`
替代已发布 gem。

## 应用源码

以下为 `starter.rb`，来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/language/ruby/examples/consumer/starter.rb)。

<!-- ruby-consumer-source: starter.rb -->

## 验收测试

以下为 `test_starter.rb`，来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/language/ruby/examples/consumer/test_starter.rb)。

<!-- ruby-consumer-source: test_starter.rb -->

## 验证

```sh
bundle install
bundle exec ruby test_starter.rb
```

程序预期输出：

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

模型是确定性 fixture，不是真实 LLM。`allowed_tools` 限制工具名，Policy 额外检查目标
参数。被拒绝的 private 目标不得到达内存效果计数器。替换为真实适配器后仍需保留这些测试。

若使用无 Bundler 的源码检出，可运行 `ruby -I language/ruby/lib test_starter.rb`；
该路径不算独立消费者证据。

## 范围

本 starter 仅证明指定 gem 与 fixture 行为，不包含治理负向矩阵，也不证明真实身份、
持久审批、效果对账或隔离。后续参考 [Ruby 实现指南](../languages/ruby/index.md)及
[安全模型](../security/index.md)。
