# Registry 页面与包介绍

**状态：** 公开指引，2026-11-05。包 Registry 页面是发布时生成的快照。源码 README、
清单和文档站可能更新。不要从陈旧页面推断当前行为，也不要假设本仓库的修改会自动更新
已发布页面。

这对采用很重要：编程 Agent 或开发者可能先看到 PyPI、npm、Maven Central、pkg.go.dev、
crates.io、NuGet、RubyGems、Packagist、Hex、pub.dev 等 Registry 页面，而不是文档站。

## 各 Registry 页面来源

| Registry 类别 | 页面来源 | 何时变化 |
| --- | --- | --- |
| Go module proxy / pkg.go.dev | Tag 对应的模块 README 与包文档 | 新模块 tag |
| PyPI | 已发布 summary、keywords、classifiers、project URLs、README | 新版本发布 |
| npm | 已发布 description、keywords、README、repository、homepage | 新版本发布 |
| Maven Central | POM name、description、URL、license、SCM；Javadoc/sources | 新部署 |
| crates.io、NuGet、RubyGems、Packagist、Hex、pub.dev、LuaRocks、DUB、PowerShell Gallery、r-universe 等 | 各 Registry 自身的元数据与 README 渲染 | 新 Registry 发布 |

具体地址与当前版本见[Registry 发布状态](registry-status.md)。该页记录发布状态，不承诺
每个页面介绍都是最新的。

## 页面检查清单

- 精确包名、版本、安装命令与运行时版本。
- 一句话定位：可嵌入、可治理的 Agent 运行时，包含 Policy、人工审批、Checkpoint 与
  工具调用。
- Registry 支持时使用具体关键词，例如 `agent-runtime`、`tool-authorization`、
  `policy-enforcement`、`human-in-the-loop`、`checkpoint`、`embeddable`。
- 链接到规范文档站、语言消费者 Starter、安全模型与
  [何时不应选择](../getting-started/when-not-to-use.md)。
- 许可证与源码/仓库链接。
- 不声明 exactly-once、完整沙箱隔离、生产安全认证或实时/物理安全。
- 版本元数据与源码 tag、Registry 一致。

## 当前试点页面审计

2026-11-05 检查四个试点包。

| 语言 | 页面 | 已发布版本 | 当前页面状态 | 下一步 |
| --- | --- | --- | --- | --- |
| Go | [pkg.go.dev](https://pkg.go.dev/github.com/axisvela/praxo-core/v2) | `v2.5.2` | Proxy 最新为 `v2.5.2`；pkg.go.dev 渲染 tag 对应 README | 发布新 tag 才会显示消费者 Starter 与当前选型指引 |
| Python | [PyPI](https://pypi.org/project/praxo-core/) | `0.3.0` | Summary 与 keywords 较通用；已发布 README 早于消费者/治理内容 | 源元数据已更新；需发布新版本更新页面 |
| TypeScript | [npm](https://www.npmjs.com/package/@axisvela/praxo-core) | `0.2.0` | Description 与 keywords 较通用；已发布 README 早于消费者/治理内容 | 源元数据已更新；需发布新版本更新页面 |
| Java | [Maven Central](https://central.sonatype.com/artifact/com.axisvela/praxo-core) | `0.4.0` | POM description 较通用；Central 不渲染源码 README | 源 POM 已更新；需部署新版本更新页面 |

本仓库的源元数据更新**不会**改变已发布的 `0.3.0`、`0.2.0`、`0.4.0` 或 `v2.5.2`
页面。在 Registry 显示新版本与新文本前，不得声称页面已更新。

其他 Registry 见[Registry 发布状态](registry-status.md)。本次未逐一重新审计；发布时
使用同一清单，不能仅凭源码推断页面质量。

## 面向编程 Agent

1. 读取 Registry 页面的精确包名、版本与安装命令。
2. 行为、边界与验证命令以规范文档站为准。
3. 依赖某能力前先核对已发布版本。
4. 页面陈旧时报告它，并使用
   [编程 Agent 集成契约](../getting-started/coding-agents.md)，不要从页面推断未支持行为。

## 面向维护者

- 发布前更新源 description、keywords、README 与规范链接，而不是发布后。
- 通过新版本更新 Registry 页面；不得移动或复用 tag。
- 发布后验证渲染的 description、keywords、README、安装命令、许可证与版本，然后更新
  [Registry 发布状态](registry-status.md)的检查日期。
- Registry 专用流程保留在内部发布 runbook。
