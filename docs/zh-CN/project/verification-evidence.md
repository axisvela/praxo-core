# 验证证据

**状态：** 公开证据摘要，2026-11-22。

本页汇总 PRAXO-CORE 当前可以支持的验证声明。它是公开摘要，不是生产认证、渗透测试，也不表示
每个语言实现和部署都会继承相同结果。完整运行记录和环境日志保存在受限内部存储；本页只记录
证据级别、结果和剩余限制。

记录要求见[测试证据规范](../contributing/test-evidence.md)：环境、配置、过程、数据、结果和发现。

## 证据级别

| 级别 | 含义 |
| --- | --- |
| 契约/单元 | 确定性仓库测试、fake、向量或 API 快照 |
| 本地集成 | 真实本地二进制和数据库，loopback，可丢弃状态 |
| 独立/生产 | 独立方复现或部署环境观察 |

除非某一行明确说明，当前公开证据不建立第三级。源码标签、矩阵中的 `complete` 或向量通过
都不是生产证据。

## 当前证据

证据按领域分组；每一行只对其注明的 revision、产物和日期负责。

### Core、执行与真实模型

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| Go Core | Tests、vet、build、API snapshot、race、fuzz 和 module-security CI；当前 main 与发布工作流检查；`v2.10.0` 为当前版本（2026-11-20）；`current-go-consumer` CI 任务从 Registry 安装推荐版本并运行确定性 allow/deny 检查；`v2.6.0` 可从公共 module proxy 在干净外部模块解析；另行记录的干净外部模块安装与最小 agent smoke 覆盖 `v2.5.2` | 契约/单元 + CI + 本地集成 | JSON Schema 和 plugin manifest fuzz 曾在 10s deadline 失败、rerun 通过；慢输入风险仍在调查；tag 提交的 `current-go-consumer` CI 任务从 module proxy 安装 `v2.9.0` 并运行确定性 allow/deny 检查；pkg.go.dev 于 2026-11-16 显示 `v2.9.0`；安装证据仍由 CI 驱动，不是独立非作者消费者 |
| Live-model Ollama 交叉验证 | Go `qwen3.5:4b` 与 TypeScript/Python `qwen2.5:0.5b` 各完成一次本地 Ollama 的 `get_time` 工具调用路径。Python 使用注入的 `http.client` transport，因为本机标准 `urllib` 挂起 | 本地集成 | 一个本地端点/平台；Python transport 是本地 workaround，不是文档化 adapter 路径；托管端点、计费调用和独立复现未测试 |
| Go 长时操作配方 | 文件存储覆盖幂等提交、响应丢失、子进程重启、独立 verifier、带 lease 过期/续期/撤销的 fencing、rename 前后确定性故障注入、损坏状态失败关闭、带 health/readiness、基础 metrics、示例 Prometheus scrape/留存/告警配置（仅配置校验；无 live collector）、环境变量配置、file-based token/secret 轮换（签发属外部）与优雅退出的独立服务二进制、可配置 file/SQLite/Postgres lease 后端与 reload-modify-save（SQLite 已验证；Postgres gated 测试需 `PRAXO_POSTGRES_DSN`，本环境未验证）、rename 边界前后进程级崩溃、gated 100 提交负载/故障测试与干净检出复现脚本、使用自己 token/密钥的独立 verifier 二进制，以及无 lease 时的并发写入者边界测试 | 契约/单元 + 本地集成 | L4 应用配方；没有生产部署、live collector/留存/告警、OS 级断电、生产 lease 协调、可信时钟或 exactly-once |
| 代表性端到端链路 | Go `examples/representative-chain`：真实 Ollama `qwen3.5:4b` → MCP `record` 工具 → 最终参数策略 → 受治理子代理委派 → OTel span 与 loopback Harmovela 事件 → 编辑后拒绝且零效果。2026-11-17 记录：输出 `DONE`、效果 parent=1/child=1、子代理调用 2 次、10 个 span、10 个事件、拒绝效果 0 | 本地集成 | 一个本地模型/平台；内存 MCP 与 loopback Harmovela；不是远程或生产部署；没有独立复现、负载或故障测试 |
| Python 代表性链路 | `language/python/examples/representative-chain`：确定性父子代理 → MCP `record` 工具 → 最终参数策略 → 受治理委派 → OTel/Harmovela 内存 transport → 编辑后拒绝且零效果。2026-11-17 记录：输出 `DONE`、效果 parent=1/child=1、子调用 2 次、7 个 span/事件、拒绝效果 0 | 契约/单元 | 确定性模型、内存 MCP 与 sink transport；不含 live provider、远程服务、身份或生产证据；补充 Go 真实模型链路 |
| TypeScript 代表性链路 | `language/typescript/examples/representative-chain`：确定性父子代理 → MCP `record` 工具 → 最终参数策略 → 受治理委派 → OTel/Harmovela 内存 transport → 编辑后拒绝且零效果。2026-11-17 记录：输出 `DONE`、效果 parent=1/child=1、子调用 2 次、7 个 span/事件、拒绝效果 0 | 契约/单元 | 确定性模型、内存 MCP 与 sink transport；不含 live provider、远程服务、身份或生产证据；补充 Go 真实模型链路 |
| 跨语言代表性链路 | Go 真实模型链路，以及 Python、TypeScript、Java、C#、Rust、R、C、C++、Fortran、COBOL、PHP、Ruby、Elixir、Erlang、Lua、Perl、V、Nim、Dart、Julia、D、OCaml、Haskell、Zig、MATLAB/Octave 共享实现、Delphi / Free Pascal、Objective-C、Swift、PowerShell 的确定性链路。每条覆盖 MCP-style record、最终授权、子委派、OTel/Harmovela 事件和编辑后零效果拒绝。2026-11-17（Swift 与 PowerShell 为 2026-11-18）记录：确定性链路输出 `DONE`，效果 parent=1/child=1，子调用 2，至少 3 类事件，拒绝效果 0；Perl/V/Nim/Dart/Julia/D/OCaml/Haskell/Zig/MATLAB-Octave/Delphi/Swift/PowerShell 为 10 个 span/事件，Objective-C 为 7；MATLAB/Octave 证据仅限 GNU Octave 11.3.0，原生 MATLAB 未验证；Delphi 证据为 Free Pascal 3.2.2，商业 Delphi 兼容性未验证；Objective-C 证据为 clang/GNUstep，Apple Foundation 未验证；Swift 证据为 Windows 上直接 `swiftc`/`lld` 链接的 Swift 6.4.2，SwiftPM `swift build` 和 macOS 运行时未验证；PowerShell 证据为 .NET 11 上的 PowerShell 7.7.0，使用为 `net8.0` 构建的共享 C# Core，不是独立 PowerShell 运行时；C 17/17、C++ 8/8 ctest；COBOL 全量套件包含该链路；Fortran 直接 20 项检查 | 契约/单元 + 本地集成 | 确定性模型与内存/transport seam；不含 live provider 或远程服务；Fortran 全量门禁受本机可执行文件删除阻塞；无独立复现或生产证据 |
| 跨语言一致性 | Python、TypeScript、Java、Rust、Fortran、COBOL 兼容性实验运行确定性向量、API snapshot/signature 与 parity 检查；已记录 Linux CI 和本地运行 | 契约/单元 + CI | 仅六种语言；COBOL 已在本地 GnuCOBOL 和 Linux CI 验证；不含 provider、HITL、checkpoint、sandbox 或生产证据；每次运行一个平台和工具链；非作者复现待完成 |

### 发布包、身份示例与消费者运行

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| Python 已发布包 | PyPI 已从源码标签 `python/v0.10.0` 发布 `praxo-core==0.10.0`。Docs CI 发布升级检查安装 `0.2.4`，运行未改动消费者与治理检查，升级到 `0.10.0` 后再次通过。历史本地检查覆盖 `0.3.2` 和 `0.2.4` | Registry 发布 + CI 升级 | 一个版本对；未记录 CI 之外的 `0.10.0` 消费者安装；一个平台/工具链；不是独立或非作者消费者；不含 provider 或生产证据 |
| Python 发布包升级（历史版本对） | `scripts/test_python_upgrade.py` 安装 PyPI `0.2.4`，运行未改动消费者 fixture 与治理兼容检查，升级到 `0.3.0`，再运行完整 starter/治理套件 | CI + Registry 升级 | 一个版本对；不证明任意升级路径、独立消费者或生产行为 |
| TypeScript 已发布包 | npm `@axisvela/praxo-core@0.9.0` 已从源码标签 `typescript/v0.9.0` 发布。Docs CI 发布升级检查将未改动消费者从 `0.1.5` 移到 `0.9.0` 并通过治理检查。示例锁文件已改用 registry `0.9.0` integrity；此前沿用 `0.8.1` integrity 导致 `npm ci` 报 EINTEGRITY | Registry 发布 + CI 升级 + 全新锁文件安装 | 一个版本对；Docs CI 安装由 CI 驱动，不是独立消费者；一个平台；不含 provider 或生产证据 |
| TypeScript 发布包升级（历史版本对） | `scripts/test_typescript_upgrade.py` 安装 npm `0.1.5`，运行未改动消费者与治理兼容检查，升级到 `0.2.0`，再运行完整 starter/治理套件 | CI + Registry 升级 | 一个版本对；不证明任意升级路径、独立消费者或生产行为 |
| Rust 已发布 crate | crates.io `praxo-core==0.10.0` 已从源码标签 `rust/v0.10.0` 发布。发布工作流在发布前运行 `cargo test`、conformance、API snapshot 和 package dry-run。已记录的本地 registry 安装 smoke 覆盖 `0.1.4` | Registry 发布 + 发布工作流门禁 | 未记录 `0.10.0` 的发布后消费者安装；一个平台；不是独立消费者；不含 provider 或生产证据 |
| Dart 已发布包 | pub.dev 已从源码标签 `dart/v0.7.0` 发布 `praxo_core==0.7.0`。先前干净项目安装 `0.6.1` 并通过确定性消费者检查；`0.7.0` 发布工作流通过 conformance、API snapshot、tests、dry-run 和 archive 检查，未重跑发布后安装 | Registry 发布 + 干净项目安装 smoke | 一个平台；同机项目，不是独立或非作者消费者；未验证真实 provider 或目标平台；pub.dev 分数/下载量不是采用证据 |
| Ruby 已发布 gem | RubyGems `praxo-core==0.9.2` 已从源码标签 `ruby/v0.9.2` 发布。发布工作流运行 conformance、API snapshot、原生测试、gem build、隔离 Bundler 检查和发布。`0.9.2` 更新 RubyGems README 与 gem 描述；`0.9.1` 移除了未声明的 `base64` 依赖 | Registry 发布 + 发布工作流门禁 + CI 消费者 | CI `current-ruby-consumer` 于 2026-11-21 安装发布包并通过 allow/deny starter（run `44913820352`）；一个平台；不是独立消费者；不含 provider 或生产证据 |
| Lua 已发布 rock | LuaRocks `praxo-core==0.8.1-1` 已通过 `.github/workflows/lua-release.yml` 发布；工作流构建 source rock、在干净目录安装、运行安装后 smoke 并发布。`0.8.1-1` 扩展 rockspec 描述与 README | Registry 发布 + 发布工作流安装 smoke + CI 消费者 | CI `current-lua-consumer` 于 2026-11-21 安装 `0.8.1-1` 并通过（run `44917317881`）；一个平台；不是独立消费者；不含 provider 或生产证据 |
| PHP 已发布包 | Packagist 从 split 标签 `v0.8.1` 发布 `axisvela/praxo-core==0.8.1`。2026-11-18 使用 Composer 2.11.2 和全新缓存安装；`composer test` 输出 `php consumer tests passed`。源码标签 `php/v0.9.0` 更新，但 Packagist 仍列 `0.8.1` | Registry 发布 + 全新 Composer 安装 + 发布包消费者 | Windows / PHP 8.5.12；按命令启用 TLS 扩展并指定可信代理 CA，未关闭证书校验。一个平台；不是独立消费者；不含 provider 或生产证据 |
| C# 已发布包 | `Praxo.Core==0.10.0` 已从源码标签 `csharp/v0.10.0` 发布。发布工作流构建、测试、打包并推送；公开 NuGet 索引列出 `0.10.0` | Registry 发布 + 发布工作流门禁 | 未记录 `0.10.0` 的干净消费者安装；一个平台；不是独立消费者；不含 provider 或生产证据 |
| C# OIDC/JWKS 服务认证 | `language/csharp/examples/service` 使用 issuer/audience 检查、Provider 发现、5 分钟 JWKS 缓存和对未知 `kid` 的一次刷新验证 RS256/RS384/RS512 JWT。loopback discovery/JWKS 测试覆盖允许、错误 audience、过期 Token、错误 issuer、未知 key 与 Provider 不可用；运行 `dotnet run --project language/csharp/examples/service -- --test`（2026-11-22） | 契约/单元 + 本地 loopback | 一个示例与平台；没有 hosted 身份提供商、密钥轮换、撤销集成或独立复现；不是身份提供商或生产安全保证 |
| Java OIDC/JWKS 服务认证 | `language/java/examples/service` 实现相同的 RS256/RS384/RS512、Provider 发现、JWKS 缓存、issuer/audience、tenant 与失败关闭行为，源码包含 loopback discovery/JWKS 测试；`mvn -q -f language/java/examples/service/pom.xml compile exec:java -Dexec.args=--test` 在 Linux CI 通过（GitHub Actions run `45005327661`，Temurin 21.0.13，2026-11-22） | Ubuntu CI 运行时 | 本机 Windows `java`/`javaw` 在 main 前挂起；一个 CI 平台；没有 hosted Provider、密钥轮换、撤销集成或独立复现 |
| Ruby OIDC/JWKS 服务认证 | language/ruby/examples/service 使用 Provider 发现、5 分钟 JWKS 缓存、issuer/audience、tenant 与失败关闭验证 RS256/RS384/RS512 JWT。脚本化 transport 覆盖允许、错误 audience、过期 Token、错误 issuer、未知 key 与 Provider 不可用；
uby language/ruby/examples/service/service.rb 在 Ruby 3.4.12 下通过（2026-11-22） | 契约/单元 | 脚本化 transport，不是 hosted Provider；没有密钥轮换、撤销集成或独立复现 |
| PHP OIDC/JWKS 服务认证 | language/php/examples/service 实现相同的 RS256/RS384/RS512、Provider 发现、JWKS 缓存、issuer/audience、tenant 与失败关闭检查。php ... service.php 在启用 OpenSSL 的 PHP 8.5.12 下通过（2026-11-22） | 契约/单元 | 脚本化 transport，不是 hosted Provider；没有密钥轮换、撤销集成或独立复现 |
| Rust OIDC/JWKS 服务认证 | language/rust/examples/service/src/oidc.rs 使用 Provider 发现、5 分钟 JWKS 缓存、issuer/audience、tenant 与失败关闭验证 RS256/RS384/RS512 JWT。静态签名向量与脚本化 discovery/JWKS 覆盖允许、错误 audience、过期、错误 issuer、未知 key 与 Provider 不可用；cargo test 已在 Linux CI（run 45012247475，2026-11-22）通过 | CI 契约/单元 | 静态 fixture 与脚本化 transport；没有 hosted Provider、密钥轮换、撤销集成或独立复现 |
| Haskell 已发布包 | Hackage `praxo-core-0.8.0` 已从源码标签 `haskell/v0.8.0` 发布。发布工作流运行原生测试、API/parity 检查和 `cabal sdist`/发布 | Registry 发布 + 发布工作流门禁 | 未记录 `0.8.0` 的发布后消费者安装；一个平台；不是独立消费者；不含 provider 证据 |
| MATLAB File Exchange 包 | File Exchange 条目 `185166` 的已发布版本为 `PRAXO-CORE 0.5.0`；源码标签 `matlab/v0.8.0` 已存在，`0.8.0` 上传待完成 | Registry 发布 | 未记录 MATLAB 运行时验证和消费者安装 smoke；Octave 验证不代表 MATLAB 行为 |
| PowerShell Core | PowerShell Gallery `praxo-core-ps==0.8.1` 已发布并记录于 registry metadata。发布工作流构建 C# Core、运行 wrapper 测试与 API snapshot，Gallery 报告 `0.8.1` 已发布 | Registry 发布 + 发布工作流门禁 + CI 消费者 | CI `current-powershell-consumer` 于 2026-11-21 从 PSGallery 安装 `0.8.1` 并通过 allow/deny（run `44917317881`）；一个平台；不是独立消费者；不含 provider 证据 |
| Perl 已发布包 | CPAN `Praxo-Core==0.7.1` 已从源码标签 `perl/v0.7.1` 发布。发布工作流运行 conformance、API snapshot、测试和 `make dist` 后发布。`0.7.1` 发布 `README.pod` 而非 Markdown | Registry 发布 + 发布工作流门禁 + `0.6.1` 隔离 `cpanm` 安装记录 | 未记录 `0.7.1` 的发布后消费者安装；MetaCPAN 索引可能滞后；一个平台；不含 provider 证据 |
| R 源码发布 | 源码标签 `r/v0.11.0` 已创建，`r-release` 工作流通过 build/check。r-universe 已于 2026-11-21 从源码提交 `d59cb301` 重建 `praxocore==0.11.0` | 源码发布 + r-universe 重建 | 无发布后 R 消费者安装；一个平台；不含 provider 或生产证据 |
| Swift 源码发布 | 源码标签 `swift/v0.7.1` 与 split 标签 `0.7.1` 已推送；split 仓库包含更新后的 Package.swift、Sources、Tests、examples 和 API snapshot。核对时 Swift Package Index 仍列 `0.7.0` | 源码发布 + split 标签已推送 + SPI 索引待完成 | 未记录 Swift 构建/测试或发布后消费者运行；macOS 运行时未验证；一个平台；不含 provider 或生产证据 |
| Elixir 已发布包 | Hex `praxo_core==0.10.0` 已从源码标签 `elixir/v0.10.0` 发布。发布工作流运行 conformance、API snapshot、原生测试和 Hex 发布 | Registry 发布 + 发布工作流门禁 | 未记录 `0.10.0` 的发布后消费者安装；一个平台；不是独立消费者；不含 provider 证据 |
| Erlang 已发布包 | Hex `praxo_core_erlang==0.9.0` 已从源码标签 `erlang/v0.9.0` 发布。发布工作流运行 conformance、API snapshot、原生测试和 Hex 发布 | Registry 发布 + 发布工作流门禁 | 未记录 `0.9.0` 的发布后消费者安装；一个平台；不是独立消费者；不含 provider 证据 |
| D 已发布包 | DUB/code.dlang.org 列出 `praxo-core==0.6.1`（来自 split 标签 `v0.6.1`）。源码标签 `d/v0.7.0` 更新；0.7.0 功能未包含在 split 包中 | Registry 发布 | 未记录 `0.6.1` 的编译或独立消费者 smoke；一个平台；不含 provider 或生产证据 |
| Java 已发布包 | Maven Central `com.axisvela:praxo-core:0.11.0` 已从源码标签 `java/v0.11.0` 发布，包含 sources、javadoc 和 GPG 签名。早先 tag 推送只运行 build-only，因此 consumer pin 在 publish 前移动时未被发现；docs CI 全新消费者安装已解析 `0.11.0` 并通过 starter/治理检查（run `44731906136`） | Registry 发布 + Central 校验 + 全新消费者安装 | Hosted Docs CI 通过；不是独立消费者；本机 Maven/JVM 执行挂起；一个平台；不含 provider 或生产证据 |
| Java 发布包升级（历史版本对） | `scripts/test_java_upgrade.py` 从 Maven Central 解析 `0.3.0`，运行未改动消费者与治理兼容检查，升级到 `0.4.0`，再运行完整 starter/治理套件 | CI + Registry 升级 | 一个版本对；不证明任意升级路径、独立消费者或生产行为 |
| 扩展消费者 Starter（Ruby/PHP/Elixir/Lua） | `examples/consumer-ruby`、`consumer-php`、`consumer-elixir`、`consumer-lua` 的确定性允许/拒绝 Starter 在源码模式本地通过。已记录的 registry 安装检查覆盖 RubyGems `praxo-core==0.4.1`、Hex `praxo_core==0.4.1`、LuaRocks `praxo-core==0.4.1-1` 和 Composer `axisvela/praxo-core==0.4.1`；这些是历史版本。当前发布版本见 Registry Publication Status | 契约/单元 + 历史本地 registry 安装 | 扩展语言 Starter；不含治理负向矩阵；一个平台；不含 provider、身份、隔离或生产证据 |
| 消费者测试模板 fixture 运行 | 2026-11-22 对维护者自有消费者 fixture 运行模板命令：Go `go test -mod=readonly -run Governed ./...` 通过；Python `test_governed.py` 在 `PYTHONPATH=language/python` 下 5/5 通过；TypeScript `npm test` 9/9 通过；C# 输出 allow/deny；Rust 在 `CARGO_HTTP_CHECK_REVOKE=false` 下输出 allow/deny；Ruby、PHP、Elixir、Lua 分别打印通过信息（Lua 需从仓库根目录运行）；Java `mvn -q test` 在本地 JVM 启动器上 180 秒内未完成 | 契约/单元 + 本地 fixture 运行 | 维护者自有 fixture，不是外部消费者；Python/Ruby/Elixir/Lua 使用源码或本地包路径；Java 使用 CI 证据而非本次本地运行；Rust 需要本地 TLS 撤销检查变通；一个平台和工具链；不含 provider、身份、隔离或生产证据 |
| Python 结构化输出应用 | `language/python/examples/structured-output-app` 将文本目录转换为受校验 JSON-lines 结果，单独记录被拒绝的模型输出，并跳过已成功的输入。2026-11-22 在源码检出中设置 `PYTHONPATH=language/python` 记录：首轮 `processed=1 skipped=0 failed=1`，续跑 `processed=0 skipped=1 failed=1`；`test_app.py` 2/2 通过；示例已加入 `ci-examples` | 契约/单元 + 本地应用运行 | 维护者 fixture/源码模式；默认确定性模型；JSON-lines 文件不是数据库、队列或 exactly-once 账本；不含真实端点、外部消费者或生产证据 |
| C#、Rust、Java live-model 本地尝试 | 2026-11-22 本地 Ollama 端点对 Python `http.client` 的 OpenAI-compatible 请求在 3.37 秒内返回，独立 C# Agent 使用 OpenAI-compatible Adapter 在本地 Ollama 上完成真实 `get_time` 工具调用（3.71 秒）。完整 C# live-model 可执行文件在当前 shell 仍未输出首行；Rust live-model 的 `cargo run` 在 180 秒内未完成依赖解析与构建；本地 Java live-model 因 JVM 启动器挂起未运行。C# 示例现在对 loopback URL 禁用代理，Rust live-model 依赖已更新为 `praxo-core==0.10.0` | 本地尝试 / 阻塞 | 未记录成功的完整 C#/Rust/Java live-model 运行；可用的 C# Agent 使用临时项目，不是示例可执行文件；这些是本地工具链和进程执行环境限制，不是 Provider 证据；Go、Python、TypeScript 的本地 Ollama 运行仍是已记录的 live 证据 |

### 跨语言行为与集成安全

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| 跨语言委派治理 | 全部十六种 wired 语言以及 Perl、V、Nim、Dart、Julia、D、OCaml、Haskell、Zig、MATLAB/Octave（共享实现）、Delphi / Free Pascal 都有应用级负向检查，覆盖子范围收窄、父子策略组合、兄弟预算、深度/子任务限制、取消后零效果和最终参数重授权。2026-11-17 记录：Go/Python/TypeScript/Rust/R/PHP/Ruby/Elixir/Erlang/Lua 各 6/6；C 16/16 ctest；C++ 7/7 ctest；COBOL 全量套件含 6 个治理用例；Fortran 直接运行 23 项检查；C# 通过 ProjectReference 6/6；Java 仅编译；Perl/V/Nim/Dart/Julia/D/OCaml/Haskell/Zig/MATLAB-Octave/Delphi 各 6/6 | 契约/单元 + 本地集成 | 应用级示例，不是 Core 强制继承；Fortran 全量门禁受本机可执行文件删除阻塞，Java 运行时受 JVM 挂起阻塞；MATLAB 证据仅限 GNU Octave；Delphi 证据为 Free Pascal 3.2.2；无独立复现或生产证据 |
| 跨语言 agent 行为 | 全部十六个已接入语言在源码中通过二十个授权、生命周期、取消、输入校验、调用上限、并行工具、run 隔离、PII、checkpoint、容量、SSE 截断、流失败和 HITL 决策场景。agent-capable 语言使用场景级或 self-test 覆盖，扩展语言使用原生套件覆盖；COBOL、Lua、PHP 和 Fortran 的并行工具委托给调用方提供的批处理回调。其他实现属于 optional。`b6218e5` 的 clean-tree CI 报告记录 320 passed、0 unsupported、无失败 | 场景测试 + CI | 十六个已接入语言在源码中均达到 20/20；部分扩展行为是套件级覆盖，失败不能定位到具体场景；`4ffd83b` 的本地报告是历史证据，不是当前证据；不是吞吐/压力测试，也不是完整功能对齐、provider、sandbox 或生产证据 |
| 受治理工作区 | Policy 必需配置、最终参数授权、单次审批、审批后修改、排队撤销、依赖失败关闭 | 契约/单元 | 示例级契约；不是 Core Profile、可信身份服务或持久审批存储 |
| 上下文信任 | Memory、Skill、工具结果和摘要来源分离；批准 Skill 摘要绑定；文本恢复；拒绝晚期 System 注入 | 契约/单元 | 显式示例路径；不是通用 Prompt Injection 过滤器、来源认证或持久 lineage 证明 |
| 隔离能力 | Windows path/process/WASM 控制；Linux path/symlink 的 verbose CI job；本地 VFS 在 policy 检查后使用 `os.Root` 执行实际操作 | 契约/单元 + CI | Windows symlink 因权限 SKIP；policy 决策仍是 check-then-use，Linux cgroup v2、WASM fuel 和独立复核仍开放 |
| 工作区适配器 | E2B、Daytona、OpenSandbox、CubeSandbox 的共享 conformance 和 fake-provider 测试 | 契约/单元 | 所有 live provider 测试因缺少凭证 SKIP；未晋级 contract |
| OpenTelemetry | 可运行内存示例生成 `run.started`、`tool.call`、`run.completed`；allowlist 排除工具参数/结果 | 示例 + 单元 | 未验证 collector、OTLP 后端、采样、保留或生产遥测 |
| A2A 互操作 | Google ADK 消费已发布 Core `v2.5.1` A2A，无本地 Core replace；成功、拒绝、失败、超时、认证、TLS、跨源和并发 fixture | 本地集成 | Loopback 确定性 fixture，不是部署 peer 或生产负载 |
| Agent IAM 契约 | Direct 与 gateway 形状的 Agent IAM 示例对契约 fake；凭证时间窗、key、签名和主体字段检查 | 契约/单元 | NOMIVELA/EIDOVELA/AEGIVELA 响应为 fake；demo 没有 proof 重放缓存或请求体绑定 gateway assertion |

### 编程 Agent 与采用

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| 编程 Agent Skill 发现 | Claude Code `2.1.196` 在临时 skills 目录插件中安装 `agent-skills/praxo-integration`；`plugin list` 显示已加载，`plugin details` 列出 Skill 组件（2026-11-08，`bdd36d7`；issue #15） | 本地结构检查 | 仅该工具和平台；该 CLI 未执行模型任务或发布包集成；不是采用证据 |
| 编程 Agent Skill 任务 | opencode `1.18.18` 从项目本地 `.opencode/skills/praxo-integration/SKILL.md` 发现 `agent-skills/praxo-integration`，并使用已发布 PyPI `praxo-core==0.3.2`、显式工具范围与 allow/deny 测试完成确定性 Python 任务（3/3 通过；模型 `deepseek/deepseek-flash`；Python 3.14.6；2026-11-08，`7004a08`） | 本地结构检查 + 本地任务执行 | 仅一个工具、一个任务、一个平台；首次通过且无需修复；未覆盖治理负向矩阵、live 模型、真实身份、持久审批、效果提交、exactly-once 或隔离；不是采用证据 |

### 产品与具身证据

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| AKROVELA 嵌入 PRAXO-CORE | AKROVELA 通过产品侧适配器嵌入已发布 PRAXO-CORE `v2.10.0`：精确操作工具、强制 Policy、受限预算、脱敏遥测与 PostgreSQL Run/对账日志。AKROVELA 仓库记录使用测试模型和本地 PostgreSQL 的确定性 P1 切片（`b5e5da9`，2026-11-08）、F5 本地 API/PostgreSQL 仿真（`a5e8e1d`，2026-11-22）与 E1-E8 确定性/本地组件矩阵（`f8fd4d7`，2026-11-22）。F5 运行 6/6 用例通过，重复提交保持幂等、scope 不匹配返回 `403`、API 终态重启保留 receipt，`full_api_e2e=local_dev_passed`、`database_receipt_durability=terminal_restart_verified`、`mid_execution_crash_recovery=verified`；`stage_3_4_p2_acceptance=not_claimed`。E1-E8 矩阵通过全部八项要求；这不是 P2 验收。G1-G8 确定性/本地组件矩阵在 `907b1eb`（2026-11-22）映射 46 个测试，全部通过，包括 G2 未暴露工具拒绝与 G6 装配、压缩、offload、恢复；G2/G6 仿真不适用于 F5 直接操作 API，因此不声称完整 P2 验收。产品已于 2026-11-22 在 `9ac0e53` 从 Core `v2.6.0` 升级到 `v2.10.0`，并在 `054e98a` 记录验证；`go build ./...`、`go vet ./...` 与 `go test ./...` 通过，包括针对一次性本地 PostgreSQL 17 数据库的 PostgreSQL-gated recorder/runtime 测试。 | 本地集成（产品仓）；组件/fixture 范围 | 没有生产模型 provider、Agent HTTP 端点、真实 ROS 2/Gazebo/Linux 执行、硬件效果、独立观测源/验证者、live KINETOVELA 集成或 E1-E8 试点验收；F5 API 运行使用模拟 bridge/source 与一次性本地数据库；E1-E8 与 G1-G8 矩阵是确定性/本地组件证据，不是 P2 仿真验收；G1-G8 的 G2/G6 仿真不适用；产品侧证据，不是 Core 验收或独立采用 |
| Bridge 召回面 | 对 `4bcb39c2`（2026-11-21）的 `cmd/praxo-bridge` 与 `internal/bridge` 源码审计：`run` 与 `event stream` 将请求 prompt 直接传给 `agent.Run`；未发现记忆构造、召回注入、system 角色提升或会话消息存储，`tool list` 返回空列表 | 契约/源码审计 | 仅源码审计；没有 live provider 或端到端 Bridge 记忆测试；不证明未来变更、其他工具或 provider 侧行为中不存在 |
| 集成恢复 | 真实本地 Symbivela、Ontovela、Rheovela、Orchadyn、Praxovela、LIMENORA 和 integration-domain；8 步、5 产品、4 gates、13 证据、11/11 报告检查；preserve/verify 拒绝和 silent-rerun 拒绝 | 本地集成 | 可丢弃本地数据库和固定 ID；没有生产、网络分区、并发负载、独立复现或部署验证 |
| 产品效果账本 | RHEOVELA effect/durable/crash 和 PRAXOVELA tenant-scoped effect-ledger 测试，含内存/SQLite 生命周期与对账 | 契约/单元（产品仓） | 进程内 SQLite/temp 文件；不是 live PostgreSQL 集群或跨服务事务 |

## 公开证据链接

- [兼容性实验](../languages/compatibility-lab.md) 与 [已记录的 CI compatibility job](https://github.com/axisvela/praxo-core/actions/runs/41000572198/job/123883752839)
- [行为实验](../languages/behavior-lab.md) 与 [commit `b6218e5` 的 CI behavior job](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339)

CI 链接指向已记录的运行；它们只证明该 run 所指的 revision，不证明当前 `main` 已通过。
Registry 链接指向当前已发布版本；上表的消费者 smoke 行指明实际安装的版本。

- [Registry 发布状态（当前版本与地址）](../languages/registry-status.md)
- [PyPI 上的 praxo-core 0.10.0](https://pypi.org/project/praxo-core/0.10.0/)
- [npm 上的 @axisvela/praxo-core 0.9.0](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.9.0)
- [crates.io 上的 praxo-core 0.10.0](https://crates.io/crates/praxo-core/0.10.0)
- [pub.dev 上的 praxo_core 0.7.0](https://pub.dev/packages/praxo_core/versions/0.7.0)
- [RubyGems 上的 praxo-core 0.9.0](https://rubygems.org/gems/praxo-core/versions/0.9.0)
- [LuaRocks 上的 praxo-core 0.8.0-1](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- [Hex 上的 praxo_core 0.10.0](https://hex.pm/packages/praxo_core/0.10.0)
- [NuGet 上的 Praxo.Core 0.10.0](https://www.nuget.org/packages/Praxo.Core/0.10.0)
- [Packagist 上的 axisvela/praxo-core 0.8.1](https://packagist.org/packages/axisvela/praxo-core)
- [PowerShell Gallery 上的 praxo-core-ps 0.8.0](https://www.powershellgallery.com/packages/praxo-core-ps/0.8.0)
- [MetaCPAN 上的 Praxo-Core 0.7.0](https://metacpan.org/release/Praxo-Core-0.7.0)
- [Hex 上的 praxo_core_erlang 0.8.1](https://hex.pm/packages/praxo_core_erlang/0.8.1)
- [DUB 上的 praxo-core 0.6.1](https://code.dlang.org/packages/praxo-core)
- [Maven Central 上的 com.axisvela:praxo-core 0.11.0](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.11.0/)
- [受治理工作区示例](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace)
- [受治理执行设计](../reference/governed-execution.md)
- [OpenTelemetry 可运行示例](https://github.com/axisvela/praxo-core/tree/main/adapters/otel/example)
- [A2A 互操作示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
- [Agent IAM 示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam)
- [集成恢复 demo](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/integration-recovery-local)
- [工作区适配器目录](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)
- [隔离能力评估](../security/containment.md)
- [RHEOVELA](https://github.com/axisvela/rheovela)、[PRAXOVELA](https://github.com/axisvela/praxovela) 与 [AKROVELA](https://github.com/axisvela/akrovela) 仓库

## 未声明

- 生产就绪、部署 SLO 或负载容量。
- 独立安全评审、渗透测试或合规认证。
- 通用 exactly-once 或跨服务事务。
- 外部工作区提供商的 live 验证。
- Live Postgres 验证：2026-11-09 在 Windows 上使用 PostgreSQL 18.1 的本地尝试未完成
  （服务以 `0xC0000142` 退出）；gated Postgres 测试需要 `PRAXO_POSTGRES_DSN` 和健康服务。
- 测试主机无法创建 symlink 时的 Windows symlink 隔离。
- 不同 commit、tag、二进制或依赖解析下的测试结果。
- 从源码标签推断包仓库可用性。
- CI 全绿。取消、失败或未运行的 job 都不是通过；请查看已记录的 CI 链接及其限制。

## 报告缺口

如果声明无法复现，请提交 issue，包含 commit、平台、命令、输入、预期结果、实际结果，以及
差异属于测试缺陷还是行为缺陷。不要用后续成功覆盖失败记录，二者都应保留。
