# TypeScript 独立消费者

在自己的 Node.js 应用中使用已发布的 `@axisvela/praxo-core@0.2.1`，要求 Node.js 20
或更新版本。无需检出 PRAXO-CORE 源码、API Key、模型服务或 AxisVela 产品。
安装需要 npm Registry 访问或已有缓存。

## 选择边界

适用于需要显式工具范围与 Policy 的嵌入式模型/工具循环。应用仍负责模型访问、真实身份、
持久审批、外部效果和隔离。它不是托管 Agent 平台、持久图引擎或沙箱服务。
选型前阅读[何时不应选择 Core](when-not-to-use.md)。

## 创建应用

在新的应用目录中创建精确依赖的 `package.json`，再由锁文件安装：

```sh
npm install --save-exact @axisvela/praxo-core@0.2.1
```

提交生成的 `package-lock.json`，重复验收使用 `npm ci`。不要使用 `file:`、`link:`、
仓库 URL 或本地路径替换发布包。测试会验证固定版本以及模块是否解析到应用内部。

## 应用源码

以下为 `starter.js`，直接渲染自[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-typescript/starter.js)。

<!-- typescript-consumer-source: starter.js -->

## 验收测试

以下为 `test_starter.test.js`，直接渲染自[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-typescript/test_starter.test.js)。

<!-- typescript-consumer-source: test_starter.test.js -->

## 验证

```sh
npm ci --no-audit --no-fund
npm test
node starter.js
```

程序预期输出：

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

模型是确定性 fixture，不是真实 LLM。`allowedTools` 限制工具名，Policy 额外检查目标参数。
被拒绝的调用抛出 `PolicyDeniedError`，不得增加内存效果计数。当前 API 的空允许列表不表示
deny-all。替换为真实模型适配器后仍需保留这些测试。

## 治理验收

`governed.test.js` 增加五项负向检查：

```sh
node --test governed.test.js
```

| 检查 | 必须结果 |
| --- | --- |
| 缺少必需 Policy | 应用守卫在运行前拒绝；工具零副作用 |
| 工具范围为空 | 应用守卫拒绝；工具零副作用 |
| Middleware 改变最终参数 | 最终操作重新授权；拒绝阻止副作用 |
| 审批编辑改变参数 | 编辑后的操作重新授权；拒绝阻止副作用 |
| Policy 服务错误 | 运行 fail closed；工具零副作用 |

使用[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-typescript/governed.test.js)。
守卫属于应用层：Core 保留普通 nil-policy 行为。这些检查不证明真实身份、持久审批、
效果对账或通用安全 Profile。

这些检查仅证明指定发布包与 fixture 行为，不证明真实模型质量、身份真实性、隔离、持久效果
或生产安全。后续参考[TypeScript 实现指南](../languages/typescript/index.md)及[安全模型](../security/index.md)。
