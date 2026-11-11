# Java 独立消费者

在自己的应用中使用 Maven Central 已发布的 `com.axisvela:praxo-core:0.5.0`，
要求 Java 21 或更新版本、Maven 3.9 或更新版本。无需检出 PRAXO-CORE 源码、API Key、
模型服务或 AxisVela 产品。安装需要 Maven Central 访问或已有本地仓库缓存。

## 选择边界

适用于需要显式工具范围与 Policy 的嵌入式模型/工具循环。应用仍负责模型访问、真实身份、
持久审批、外部效果和隔离。它不是托管 Agent 平台、持久图引擎或沙箱服务。
选型前阅读[何时不应选择 Core](when-not-to-use.md)。

## 创建应用

在 `pom.xml` 中声明精确依赖：

```xml
<dependency>
  <groupId>com.axisvela</groupId>
  <artifactId>praxo-core</artifactId>
  <version>0.5.0</version>
</dependency>
```

不要使用 `system` scope、本地 JAR 路径或框架源码替代构建。测试会验证 SDK 版本，
并确认 `Version` 来自已发布的 `praxo-core-0.5.0.jar`。

## 应用源码

以下为 `src/main/java/starter/App.java`，直接渲染自
[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-java/src/main/java/starter/App.java)。

<!-- java-consumer-source: App.java -->

## 验收测试

以下为 `src/test/java/starter/AppTest.java`，直接渲染自
[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-java/src/test/java/starter/AppTest.java)。

<!-- java-consumer-source: AppTest.java -->

## 验证

```sh
mvn -B test
mvn -q -B exec:java
```

程序预期输出：

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

模型是确定性 fixture，不是真实 LLM。`allowedTools` 限制工具名，Policy 额外检查目标参数。
被拒绝的调用抛出 `PraxoException`，错误码为 `AGENT_POLICY_DENIED`，不得增加内存效果计数。
当前 API 的空允许列表不表示 deny-all。替换为真实模型适配器后仍需保留这些测试。

## 治理验收

`GovernedAcceptanceTest` 增加五项负向检查：

```sh
mvn -B -Dtest=GovernedAcceptanceTest test
```

| 检查 | 必须结果 |
| --- | --- |
| 缺少必需 Policy | 应用守卫在运行前拒绝；工具零副作用 |
| 工具范围为空 | 应用守卫拒绝；工具零副作用 |
| Middleware 改变最终参数 | 最终操作重新授权；拒绝阻止副作用 |
| 审批编辑改变参数 | 编辑后的操作重新授权；拒绝阻止副作用 |
| Policy 服务错误 | 运行 fail closed；工具零副作用 |

使用[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-java/src/test/java/starter/GovernedAcceptanceTest.java)。
守卫属于应用层：Core 保留普通 nil-policy 行为。这些检查不证明真实身份、持久审批、
效果对账或通用安全 Profile。

这些检查仅证明指定发布产物与 fixture 行为，不证明真实模型质量、身份真实性、隔离、持久效果
或生产安全。后续参考[Java 实现指南](../languages/java/index.md)及[安全模型](../security/index.md)。
