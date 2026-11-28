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

- 按产品说明、开始使用/安装、示例、场景教程、参考应用、能力证据、边界和社区排序。
  教学切片或应用源码不等于端到端验收通过。
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

## 产品发现

PRAXO-CORE（也写作 **praxocore**）是可嵌入、多语言、MIT 许可的 AI Agent 框架。
两个拼写指向同一框架；别名不改变 import、模块名、包坐标或仓库名。R 现有的
`praxocore` 包名保持不变。

`language/discovery.json` 配置别名、通用和语言/生态专属 GitHub topics、发布源码拆分仓库
以及仓库名称覆盖（包括 `praxo-core-Julia`）。Registry 生成器将其写入
`language/registry-metadata.json`。MATLAB/Octave 共享实现不是独立包或镜像仓库。

中英文首页还输出 `SoftwareSourceCode` JSON-LD，包含产品名、别名、规范仓库、MIT 许可、
简介和通用发现词。这是源码软件标识，不是托管服务、用户评分或独立安全认证声明。

以下命令只验证本地配置或输出提案，不调用网络，不修改远端：

```bash
python -m scripts.discovery.sync_language_registry_docs --check
python -m scripts.discovery.repository_discovery --check
python -m scripts.discovery.repository_discovery
python -m unittest discover -s scripts -t . -p test_discovery.py -v
```

提案覆盖主仓库、22 个发现镜像和 9 个发布源码拆分仓库，检查 GitHub 的 20-topic 上限与格式。
主仓库提案保留现有描述词并补充两种产品拼写；语言仓库组合产品词与各自语言、生态词。
实际更新前必须单独授权并审核与远端的差异；提案没有接入镜像同步，不发布包、tag、分支或 topics。

这些入口可以帮助读者、搜索工具和编程工具识别框架，但不保证 SEO 排名、生成式引擎引用、
索引、包发现或采用。能力声明仍以[适配器状态](adapter-status.md)、各语言 README 和
[验证证据](../project/evaluation/verification-evidence.md)为准。

### 元数据覆盖

| 生态 | 本次源码入口 | 约束与缺口 |
| --- | --- | --- |
| PyPI / npm | description、keywords、README、规范链接 | 保留包名和版本，补充任务与生态词 |
| crates.io | description、5 个关键词、categories、README | 最多 5 个关键词，每个最多 20 个字符 |
| NuGet / PowerShell Gallery | description、包/模块 tags、README | PowerShell 使用 C# 运行时，不能宣称独立运行时 |
| pub.dev | description、5 个 topics、README | 最多 5 个 topics，不推断 Flutter 支持 |
| CPAN / opam | `META_MERGE` keywords、POD、生成的 opam tags 与 README | OCaml 发布仍待完成，本地打包不等于上架 |
| Maven Central | POM description 与规范链接 | 无标准 keywords 字段；description 提供有序入口和边界 |
| RubyGems / Hex / DUB / Nimble / V / r-universe / Octave | 原生描述与 README | 不添加不支持的关键词字段，URI 元数据不是 tags |
| LuaRocks | 当前 rockspec 简介、详细说明与 README | 不重写历史 rockspec，线上 labels 仍需单独审计 |
| Swift / Julia / C / C++ / Fortran / COBOL / Delphi / Objective-C / Zig / MATLAB | README、Registry 与编程工具入口、topics 提案 | 无通用关键词字段，外部索引和 File Exchange 元数据需要单独审核 |
| PHP / Packagist | 生成的 README、Registry 与编程工具入口、topics 提案 | Composer 元数据与完整运行时载荷已在 `0.10.2` 发布；渲染页面复审待完成 |

源码更新不会刷新既有包或 Registry 页面。后续经授权发布时，必须检查实际包内容、页面、关键词、
topics 和消费者安装再记录验收。发布源码拆分仓库需要独立审核更新；镜像分支同步不会更新这些布局或 topics。

## 公开页面审计

2026-11-26 已将 GitHub Latest 恢复到现有的
[Go `v2.9.0` Release](https://github.com/axisvela/praxo-core/releases/tag/v2.9.0)。
Go proxy 已有 `v2.11.3`，对应 GitHub Release 已发布为 latest。此次仅修正语言发布占用
Latest 的问题，不代表已补齐 Core Release 或修复不可变包 README 快照。
`scripts/release/check_public_release.py` 独立检查线上 Latest 和预期 Core Release。

审计日期：2026-11-27。发布可用性不等于页面验收。以下不可变发布快照仍有已知缺陷；
源码修改不会修复它们，仍需新版本发布并重新核对。

| 语言 | 发布证据 | 已发布版本 | 观察到的缺陷 | 验收 |
| --- | --- | --- | --- | --- |
| Go | [pkg.go.dev](https://pkg.go.dev/github.com/axisvela/praxo-core/v2@v2.11.3) | `v2.11.3` | README 安装 `@v2.11.3` 并声明 `v2.11.3` 为当前版本 | 页面复审待完成 |
| Python | [PyPI](https://pypi.org/project/praxo-core/0.11.2/) | `0.11.2` | 源码未记录缺陷 | 页面复审待完成 |
| TypeScript | [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.1) | `0.10.1` | 源码未记录缺陷 | 页面复审待完成 |
| Java | [Maven POM](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.3/praxo-core-0.12.3.pom) | `0.12.3` | SCM tag 为 `java/v0.12.3` | 页面复审待完成 |
| Rust | [crates.io](https://crates.io/crates/praxo-core/0.11.0) | `0.11.0` | 包内 README 安装 `0.9.2` | 未通过 |
| C# | [NuGet](https://www.nuget.org/packages/Praxo.Core/0.11.1) | `0.11.1` | 源码未记录缺陷 | 页面复审待完成 |
| Dart | [pub.dev](https://pub.dev/packages/praxo_core/versions/0.8.0) | `0.8.0` | 包内 README 安装 `0.7.0` | 未通过 |
| Haskell | [Hackage](https://hackage.haskell.org/package/praxo-core-0.9.0) | `0.9.0` | 包内 README 安装 `0.7.1` | 未通过 |

Go 发布文档日期为 2026-11-27；
[proxy 发布时间戳](https://proxy.golang.org/github.com/axisvela/praxo-core/v2/@v/v2.11.3.info)
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
