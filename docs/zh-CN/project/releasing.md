# 发布要求

核心、语言 Core、可选适配器和共享规范独立版本化。每次发布必须说明范围与兼容影响。

## 验证要求

- 更新对应版本文件、变更日志和用户可见的发布说明。
- 通过受影响工件的构建、测试、API 和安全检查。
- Core 通过声明范围的一致性向量与 parity 检查。
- 检查依赖许可，生成适用的 SBOM 和校验和。
- 发布包含标签、提交 SHA、版本、规范版本、Go 工具链、SBOM 范围和每个附件
  哈希的发布清单。校验和覆盖源码包、SBOM 和清单，且不包含校验和文件自身。
- 验证版本标签，优先使用签名标签，例外需要记录。
- 验证用户实际使用的分发工件可以安装。

## 自动检查

核心发布工作流在授予独立发布任务写权限之前，要求标签所指提交的完整 SHA
在 `main` 上具有成功的 `ci` 和 `docs` push 工作流。缺失、未结束、跳过、取消
或失败都会阻断发布；较早的成功不能掩盖较新的失败尝试。其他提交、分支、仓库
或 pull request 的检查不能代替。

文档构建覆盖 `main` 的每次 push，包括仅修改源码的提交，避免同 SHA 要求无法
满足；pull request 的文档构建仍按路径过滤。检查只观察验证时的 Actions 状态，
不会锁定后续重跑，也不代替兼容性、工件安装、签名与发布范围评审。工作流全绿
本身不是创建新版本标签的充分理由。

手动触发只运行所选提交的只读预检。发布任务额外要求 `v*` 标签的 push 事件，
手动运行时会跳过，因此无需创建标签或 Release 就能验证真实门禁。

## 工件证据

`release-manifest.json` 记录发布版本、标签、完整提交 SHA、规范版本、报告的 Go
工具链、SBOM 范围，以及每个附件的大小与 SHA-256。`SHA256SUMS` 覆盖源码包、
`sbom.json` 和清单。当前 SBOM 范围仅为根 Go 模块依赖，不是所有独立适配器、
语言 Core 或原生依赖的合并清单；必须保留这一区别，不能把根 SBOM 当作完整归档
清单。

| 工件 | 标签 |
| --- | --- |
| Go 核心 | `vX.Y.Z` |
| 共享规范 | `spec/vX.Y.Z` |
| 语言 Core | `<language>/vX.Y.Z` |
| 可选 Go 适配器 | `adapters/<name>/vX.Y.Z` |

既有标签不可移动。Core 必须声明支持的契约版本。根发布工作流只处理 `v*` 核心标签，
Core 或适配器的源码标签不会自动完成包管理器发布。

## 语言发布说明

每个语言 Core 的发布说明放在实现旁的 `language/<language>/CHANGELOG.md`。
语言 `README.md` 链接该文件，公开语言页面又包含 README，因此同一份文件同时服务
源码使用者和文档站点。

- 包版本、`SDK_VERSION`、源码标签和发布说明必须一致。
- `1.0.0` 之前，修复使用 patch，新增功能使用 minor，破坏性变更使用 major。
- 明确区分源码标签发布与包管理器发布，并说明发布说明描述的是哪一种。
- 按需记录 Added、Changed、Fixed 和 Compatibility。
- 不要把语言发布说明移入根变更日志或共享发布页；根变更日志只保留跨语言摘要。

Python 使用 PyPI Trusted Publishing，工作流为
`.github/workflows/python-release.yml`。`python/vX.Y.Z` 标签必须与
`pyproject.toml`、`praxo.__version__` 和 `praxo.SPEC_VERSION` 一致。手动触发默认
只构建 `build-only`；发布到 TestPyPI 或 PyPI 必须显式选择。TestPyPI 需要单独的
trusted publisher。首次创建标签前，必须在 PyPI 配置 owner、repository、workflow
文件名和 environment。PyPI 的 workflow 字段必须
精确填写 `python-release.yml`；填写通用的 `workflow.yml` 不会匹配本仓库。源码标签或构建成功都不
代表 PyPI 已完成发布。

TypeScript 使用独立的 npm 工作流
`.github/workflows/typescript-release.yml`。它校验包名、repository URL、版本和
`typescript/v*` 标签；标签默认只 stage 包，等待维护者批准。直接 `npm publish` 是
显式手动目标，并需要在 npm trusted publisher 中允许该动作。首个 npm 包已用
短期 bypass token 发布为 `0.1.2`，因为当时 staged 批准不可用；该版本不声明
provenance。npm trusted publisher 要求包已存在，因此应在下一次发布前配置
trusted publisher。不要为日常发布使用长期自动化 token。手动触发默认只
build-only。

Rust 使用 crates.io Trusted Publishing，工作流为
`.github/workflows/rust-release.yml`。`rust/vX.Y.Z` 标签必须与 `Cargo.toml`
的包版本一致。构建 job 运行测试、conformance 和 API snapshot，然后执行
`cargo publish --dry-run`；发布 job 使用 `rust-lang/crates-io-auth-action`
获取短期 token，并跳过已发布的版本。首次创建标签前，必须在 crates.io 配置
trusted publisher，workflow 文件名填 `rust-release.yml`，environment 填
`crates-io`。手动触发默认只构建 `build-only`。

Ruby 使用 RubyGems Trusted Publishing，工作流为
`.github/workflows/ruby-release.yml`。`ruby/vX.Y.Z` 标签必须与
`language/ruby/VERSION` 一致。Pending trusted publisher 的 workflow 文件名填
`ruby-release.yml`，environment 填 `rubygems`；工作流会运行 conformance、API
snapshot、原生测试、构建 gem，并使用短期 RubyGems token 推送。手动触发默认只
构建 `build-only`。

Lua 使用 `.github/workflows/lua-release.yml`。`lua/vX.Y.Z` 标签必须与
`language/lua/VERSION` 和 `praxo-core-X.Y.Z-1.rockspec` 一致。构建 job 运行
conformance、API snapshot 和原生测试，然后打包 source rock、在干净目录安装并运行
安装后 smoke，再上传工件。发布前配置 environment `luarocks` 和仓库 secret
`LUAROCKS_API_KEY`；发布 job 会跳过已发布的修订。手动触发默认只构建
`build-only`。

Perl 使用 `.github/workflows/perl-release.yml`。`perl/vX.Y.Z` 标签必须与
`language/perl/VERSION` 和 `Makefile.PL` 一致。构建 job 运行门禁、构建并测试发行包，
然后上传 CPAN tarball；发布前配置 environment `cpan` 和 secret `PAUSE_USER`、
`PAUSE_PASSWORD`。

Haskell 使用 `.github/workflows/haskell-release.yml`。`haskell/vX.Y.Z` 标签必须与
`language/haskell/praxo-core.cabal` 一致；构建 job 运行原生测试和 `cabal sdist`。
发布前配置 environment `hackage` 和 secret `HACKAGE_TOKEN`。

Elixir 使用 `.github/workflows/elixir-release.yml` 发布 Hex 包和 HexDocs。
`elixir/vX.Y.Z` 标签必须与 `language/elixir/VERSION` 一致；发布前配置 environment
`hex` 和 secret `HEX_API_KEY`。

Julia 使用 `.github/workflows/julia-release.yml` 校验标签并运行测试，然后通过
JuliaRegistrator 向 General Registry 提交 PR；不需要仓库 secret。

R 使用 `.github/workflows/r-release.yml` 执行 `R CMD build` 和 `R CMD check`。
r-universe 从 GitHub 仓库的 `language/r` 子目录构建；CRAN 提交仍需单独人工审核。

Nim 通过 `nim-lang/packages` 的 PR 列表发布，使用
`"subdir": "language/nim"`；Nimble 从 Git 标签推导版本。PowerShell 使用
`.github/workflows/powershell-release.yml`，配置 environment `powershell-gallery`
和 secret `PSGALLERY_API_KEY`。Objective-C 使用
`.github/workflows/cocoapods-release.yml`，配置 environment `cocoapods` 和
secret `COCOAPODS_TRUNK_TOKEN`。Swift、V 和桥接包需要按各自 `PUBLISHING.md`
中的拆分仓库或包格式步骤发布。

升级前查看[版本总览](../releases/index.md)、[兼容性](compatibility.md)和
[Core 支持政策](../languages/support.md)。产品版本与框架版本独立。
