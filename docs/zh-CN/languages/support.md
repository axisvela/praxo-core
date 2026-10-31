# 语言实现支持政策

Go 是参考实现。[语言支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)
记录各语言的声明范围、源码标签与 CI 覆盖；该矩阵是实现状态的规范来源。

## Framework 目标

每个独立语言实现默认以共享核心契约的原生 Framework 实现为最终目标。
Wire 是中间阶段，不是永久的产品分类。只有明确记录的语言或运行时技术限制
确实阻止完整 Framework 实现时，才将 Wire 保留为最终范围。

工具链暂缺、开发尚未完成、需求较少或维护者尚未到位，都不等于语言不支持
Framework 行为。消费者和维护门槛决定何时启动工作，不改变最终目标。
最终目标也不代表当前已经可用、承诺交付日期、具备 Go 的全部可选集成或生产就绪。

## 当前阶段与交付形式

| 当前阶段或形式 | 含义 |
| --- | --- |
| Framework（`Core`） | 在声明的公开范围内提供原生框架行为，通过共享向量验证 |
| Wire | 正在向 Framework 演进的中间实现，当前只声明序列化与 wire 范围 |
| Bridge | 通过进程或 HTTP 边界调用受维护运行时 |
| Sample | 复用已有语言实现的示例，不是另一个独立运行时 |

实现类型不是稳定性等级，也不保证拥有 Go 的全部功能。采用前应阅读具体语言的
公开 API 和限制。
Bridge、Sample 描述运行时的接入方式，不证明其语言缺乏 Framework 实现能力；
共享运行时的语言可以复用宿主 Framework，而不是重复编写 Agent 循环。

## 支持等级

成熟度记录声明范围的完成情况；支持等级记录谁负责响应问题和安全修复，两者独立。

| 等级 | 含义 | 不表示 |
| --- | --- | --- |
| `maintained` | 有明确维护者或团队、CI 和适用的安全修复 | 响应 SLA、完整 Go parity、所有 provider |
| `community` | 社区维护，尽力更新 | 响应时间、安全回移承诺 |
| `experimental` | 范围可能变化，无稳定性承诺 | 适合生产使用 |
| `deprecated` | 不再增加功能，提供迁移说明 | 未明确说明的移除日期 |

矩阵尚未为每一行发布支持等级列。在记录之前，不要从 `complete`、源码标签或包注册表可用性推断官方支持承诺。维护者确认后逐步补充。

记录支持等级时，应由负责的维护者或团队提供等级、CI job、最后验证的 tag 或 SHA，以及适用安全修复的范围。不要替他人指定支持等级，也不要把已合并的实现 PR 当作支持承诺。

## 版本与分发

- 核心、Core、适配器与契约独立版本化，每个 Core 声明其 `SPEC_VERSION`。
- 版本标签与成熟度相互独立：源码标签记录发布，成熟度记录声明范围的完成情况与验证状态。
- 源码标签不等于已发布到包管理器，应按语言页面中的安装或源码构建步骤操作。
- Python 已发布 `praxo-core==0.2.3` 到 PyPI；TypeScript 源码标签为
  `typescript/v0.1.3`，其 npm 包已于 2026-10-31 成功进入待审批 staging。
  审批通过前 `0.1.2` 仍是公开最新版本；当前 main 有未包含在该 staging 包中的新修复。
- Java 提供 Maven 源码构建方式，源码标签不证明 Maven Central 可用。
- Rust 已有源码标签 `rust/v0.1.2`，包含全部 11 个向量组、原生测试、`tool.Gateway`、`jsonschema.Schema` 和 API 快照。不包含 OpenAI adapter、VFS、plugin hosts 以及 Go context/cancellation 语义。
- Fortran 源码标签 `fortran/v0.3.0` 包含全部 11 个向量组、原生测试、API 快照
  以及集成的 PII/中间件。它不是包管理器发布；异步流不在声明范围，受限 JSON Schema 子集
  仍为部分完成。
  `0.3.0` 使用 RE2/Unicode 取代 ASCII matcher，新增原生 C++ 库依赖；历史 `0.2.2` 标签仍保留无此原生依赖的实现。
- COBOL 已有源码标签 `cobol/v0.1.2`，包含全部 11 个向量组、原生与契约测试、调用方持有状态的 scoped registry 和 API 快照。它不是包管理器发布；其余 Go 面大多为 partial，registry 无并发和 custom spec provider。
- Haskell 已有源码标签 `haskell/v0.2.0`，包含全部 11 个向量组、原生测试、API
  快照/parity 以及运行时/中间件辅助函数。未声明 Hackage 发布或生产就绪。
- Delphi/Free Pascal 已有源码标签 `delphi/v0.2.1`，在 Free Pascal 3.2.2 下通过
  全部 11 个向量组、原生测试和 API 快照/parity。商业 Delphi 编译器、其他目标
  平台和包管理器发布均未声明。
- MATLAB/Octave 已有源码标签 `matlab/v0.2.1`，在 Octave 下通过全部 11 个向量组、
  原生测试和 API 快照/parity。MATLAB 运行时、提供商适配器和包管理器发布均未声明。
- OCaml 已有源码标签 `ocaml/v0.2.0`，包含全部 11 个向量组、原生测试和 API
  快照/parity。原生 `ocamlopt` 编译、提供商适配器和包管理器发布均未声明。
- Erlang 已有源码标签 `erlang/v0.1.1`，包含原生 BEAM Core 循环、11 个向量组、
  原生测试和 API 快照/parity 清单。包管理器、提供商适配器、流式路径和生产就绪
  均未声明；可选中间件已集成，但未包含全部可选 Go 钩子。
- Lisp 已有 SBCL 桥接的源码标签 `lisp/v0.1.0`，不提供原生 Lisp 循环；转发、UTF-8、
  错误和退出码检查已在本地和 Linux CI 通过。消费者细节与包管理器发布仍待完成。
- Tcl 已有桥接包装器的源码标签 `tcl/v0.1.0`，不提供原生 Tcl 循环；本地转发、UTF-8、
  错误和退出码测试已通过，远端 CI 与包管理器发布仍待完成。
- Prolog 已有 SWI-Prolog 桥接的源码标签 `prolog/v0.1.1`，不提供原生 Prolog 循环；
  转发、UTF-8、错误和退出码测试已通过。包管理器发布与生产就绪仍未声明。

## 功能边界

Python、TypeScript、Java、C# 包含流式路径与 OpenAI 兼容适配器，不能据此推断
其他语言也具备这些能力。`complete` 表示声明范围内的契约一致性；parity 清单仍可包含
该范围之外的功能 `partial`/`planned` 行。共享向量通过不等于 Go 全功能一致、真实提供商验证、
生产就绪或包仓库发布完成。

VFS、插件宿主、调度与可选集成应以对应 Core 的 README 和 API 参考为准。
贡献要求见 [Core 设计](../contributing/core-design.md)和
[语言支持规范](../contributing/language-policy.md)。
