# Registry 页面与包介绍

**状态：** 公开审计，2026-11-27。包 Registry 页面是发布时生成的快照。源码 README、
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

每个语言源码目录还提供面向 Registry 的 `REGISTRY.md`、`llms.txt` 与 `llms.md`；
总索引见[语言 Registry 与编程 Agent 入口](https://github.com/axisvela/praxo-core/blob/main/language/REGISTRY-INDEX.md)。
这些是源码入口，不证明 Registry 页面已刷新。

生成入口区分 `source_version` 与 `published_version`。源码发布可以在 Registry 页面更新前准备；
在新 tag 发布前，消费者应安装已发布版本。准备好的源码 tag 不是 Registry 可用性的证据。

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

## 公开页面审计

2026-11-26 已将 GitHub Latest 恢复到现有的
[Go `v2.9.0` Release](https://github.com/axisvela/praxo-core/releases/tag/v2.9.0)。
Go proxy 已有 `v2.11.1`，对应 GitHub Release 已发布为 latest。此次仅修正语言发布占用
Latest 的问题，不代表已补齐 Core Release 或修复不可变包 README 快照。
`scripts/check_public_release.py` 独立检查线上 Latest 和预期 Core Release。

审计日期：2026-11-27。发布可用性不等于页面验收。以下不可变发布快照仍有已知缺陷；
源码修改不会修复它们，仍需新版本发布并重新核对。

| 语言 | 发布证据 | 已发布版本 | 观察到的缺陷 | 验收 |
| --- | --- | --- | --- | --- |
| Go | [pkg.go.dev](https://pkg.go.dev/github.com/axisvela/praxo-core/v2@v2.11.1) | `v2.11.1` | README 安装 `@v2.11.1` 并声明 `v2.11.1` 为当前版本 | 页面复审待完成 |
| Python | [PyPI](https://pypi.org/project/praxo-core/0.11.0/) | `0.11.0` | 包内 README 安装 `0.9.1` | 未通过 |
| TypeScript | [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.0) | `0.10.0` | 包内 README 安装 `0.8.1` | 未通过 |
| Java | [Maven POM](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.0/praxo-core-0.12.0.pom) | `0.12.0` | SCM tag 为 `java/v0.10.0` | 未通过 |
| Rust | [crates.io](https://crates.io/crates/praxo-core/0.11.0) | `0.11.0` | 包内 README 安装 `0.9.2` | 未通过 |
| C# | [NuGet](https://www.nuget.org/packages/Praxo.Core/0.11.0) | `0.11.0` | 包内 README 安装 `0.10.0` | 未通过 |
| Dart | [pub.dev](https://pub.dev/packages/praxo_core/versions/0.8.0) | `0.8.0` | 包内 README 安装 `0.7.0` | 未通过 |
| Haskell | [Hackage](https://hackage.haskell.org/package/praxo-core-0.9.0) | `0.9.0` | 包内 README 安装 `0.7.1` | 未通过 |

Go 发布文档日期为 2026-11-27；
[proxy 发布时间戳](https://proxy.golang.org/github.com/axisvela/praxo-core/v2/@v/v2.11.1.info)
为 2026-11-27 UTC，均不支持此前的 2026-11-16 页面验收或 2026-11-20 发布日期。
本次不声称远端修复完成。

其他发布证据见[Registry 发布状态](registry-status.md)。SPI 已索引 Swift split 包 `0.7.2`，
其非流式范围不等于主仓库 `swift/v0.9.0` 的流式范围。R r-universe `0.12.0` 的实际构建
HEAD 为 `9b417e3`，检查有 warnings，不是全部无警告通过。发布可用性不代表页面质量或运行时兼容性验收。

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

## 实际发布包验收

源码 README 修改不等于完成。下一次正式发布时，必须验证真实工件与页面：

| 证据 | 验收要求 |
| --- | --- |
| 身份 | 精确包名、版本、不可变源码 tag 与工件摘要一致 |
| 包内介绍 | 检查下载的 wheel/sdist、npm tarball、Maven POM/sources 或 Go tag，不检查 main 替代品 |
| 页面展示 | 在对应版本的公开 URL 核对定位、消费者 Starter、限制、安装方式和运行时要求 |
| 消费者安装 | 在干净消费者中安装该版本，执行文档中的确定性 smoke/允许拒绝检查 |
| 责任边界 | 说明 Core 实现、测试证据和消费者责任；Policy 需配置，沙箱接口不等于隔离，Checkpoint 不等于外部事务 |

将版本、URL、核对日期、工件哈希与观察结果记录后，才能在
[注册表发布状态](registry-status.md)标为页面已更新。索引或渲染延迟应标记待核实，不能从
发布 job 推断成功。不渲染 README 的注册表（例如 Maven Central）也需准确元数据与规范文档链接。

## MATLAB 兼容性元数据

2026-11-26 核对：[File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core)
的 `0.9.1`（源码 `matlab/v0.9.0`）引用仍为 `0.2.1`，显示“Compatible with any release”和 Windows/macOS/Linux，安装菜单又显示
R2026b 或更新版本。这些标签不是独立 MATLAB 验证证据。当前执行证据仅来自 GNU Octave
11.3.0，MATLAB 运行及实际安装包验证仍未完成。提交所有者需收窄可编辑兼容性字段，或在
Overview 顶部添加醒目限制。修改源码不会自动修改线上提交。
