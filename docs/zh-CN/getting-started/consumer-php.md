# PHP 独立消费者

在自己的应用中使用已发布的 `axisvela/praxo-core` `0.4.1`，要求 PHP 8.2 或更新版本
及 Composer 2。无需检出 PRAXO-CORE 源码、API Key、模型服务或 AxisVela 产品。
安装需要 Packagist 访问或已有 Composer 缓存。

这是扩展语言 starter，只演示 allow/deny 路径，不在四个具备治理负向矩阵的试点语言范围内。

## 选择边界

适用于需要显式工具范围和 Policy 的嵌入式模型/工具循环。应用仍负责模型访问、真实身份、
持久审批、外部效果和隔离。它不是托管 Agent 平台、持久图引擎或沙箱服务。
选型前阅读[何时不应选择 Core](when-not-to-use.md)。

## 创建应用

在 `composer.json` 中声明精确依赖：

```json
{
  "require": {
    "axisvela/praxo-core": "0.4.1"
  }
}
```

然后运行 `composer install`。验收时不要使用 `path` 仓库、本地归档或源码检出中的
`autoload.php`。

## 应用源码

以下为 `starter.php`，来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-php/starter.php)。

<!-- php-consumer-source: starter.php -->

## 验收测试

以下为 `test_starter.php`，来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-php/test_starter.php)。

<!-- php-consumer-source: test_starter.php -->

## 验证

```sh
composer install
composer test
```

程序预期输出：

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

模型是确定性 fixture，不是真实 LLM。`allowedTools` 限制工具名，Policy 额外检查目标
参数。被拒绝的 private 目标抛出带 `AGENT_POLICY_DENIED` 的 `PraxoException`，且不得
增加内存计数器。替换为真实适配器后仍需保留这些测试。

若使用无 Composer 的源码检出，starter 会回退到 `language/php/src/autoload.php`；
该路径不算独立消费者证据。

## 范围

本 starter 仅证明指定包与 fixture 行为，不包含治理负向矩阵，也不证明真实身份、
持久审批、效果对账或隔离。后续参考 [PHP 实现指南](../languages/php/index.md)及
[安全模型](../security/index.md)。
