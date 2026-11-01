# 行为实验

**状态：** 证据工具，2026-11-01。该实验不是稳定的公开 API。

行为实验在十六个已接入实现中运行具名 agent 场景，并生成一份对比报告。agent-capable 层级为 Go、Python、TypeScript、Java、Rust、R、C#；extended 层级为 C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua。其他已声明实现属于 optional，不在当前行为计划内。它回答的问题比[兼容性实验](compatibility-lab.md)更窄：当通过各实现自己的测试套件执行时，它们是否对授权、生命周期、取消、输入校验、调用上限、并行工具执行、run 状态隔离、PII、checkpoint、容量和流失败做出相同决策？

它不证明完整功能对齐、provider 行为、真实服务集成、生产就绪或安全性。报告通过只比较所列场景。

## 能力层级

行为层级与契约层级相互独立，定义见[支持政策](support.md)。

| 层级 | 语言 | 当前状态 |
| --- | --- | --- |
| Agent-capable | Go、Python、TypeScript、Java、Rust、R、C# | 每个 agent-capable 实现均为 19/19 |
| Extended | C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua | C/COBOL/Ruby/C++/Elixir/Erlang 19/19；PHP 18/19（并行工具不支持）；Lua 12/19；Fortran 11/19 |
| Optional | 其他已声明实现 | 不在当前行为计划内 |

R 和 C 现已接入。C# 与 PHP 包含三个生命周期场景；R 和 C 对原生套件实际断言的场景提供覆盖。COBOL 0.3.0 通过原生套件覆盖全部十九个场景；其中 parallel-tools 将并发执行委托给调用方提供的批处理调度器，原生测试验证批处理上限和结果顺序，而不是 OS 线程。Ruby 0.3.0 也通过原生套件达到 19/19，覆盖取消、流式回调、SSE 截断/半包、有限并行工具和按 run 隔离的调用上限。C++ 0.3.0 也通过 std::async 并行工具和原生 SSE parser 达到 19/19。Elixir 0.3.0 通过 Task.async 并行工具、取消、流式回调和原生 SSE parser 达到 19/19。Erlang 0.3.0 通过 spawned-process 并行工具和相同生命周期覆盖达到 19/19。

## 范围

下表展示四个原始核心实现的场景级证据。agent-capable 的 Rust、R、C#，以及已接入的 extended 语言，见[矩阵](behavior-lab-matrix.md)。

| 场景 | 检查的行为 | Go | Python | TypeScript | Java |
| --- | --- | --- | --- | --- | --- |
| `final-arguments` | 修改后的参数在产生效果前重新授权 | scenario | scenario | scenario | self-test group |
| `final-name` | 最终 name 同时检查 allowlist 和 policy | scenario | scenario | scenario | self-test group |
| `unchanged-single-auth` | 未变化的调用只授权一次 | scenario | scenario | scenario | self-test group |
| `initial-denial` | 初始拒绝阻止 middleware 和效果 | scenario | scenario | scenario | self-test group |
| `startup-cleanup` | before-run 失败清理已进入的 middleware 且不发 run 事件 | scenario | scenario | scenario | self-test group |
| `after-run-continue` | 前序失败后仍继续执行后续 after-run 回调 | scenario | scenario | scenario | self-test group |
| `cleanup-failclosed` | 清理失败使成功的 run 失败关闭 | scenario | scenario | scenario | self-test group |
| `model-cancel-cleanup` | 模型阶段取消会执行 after-run 并发出 failed | scenario | scenario | scenario | self-test group |
| `tool-cancel-cleanup` | 工具阶段取消会停止效果并执行 after-run | scenario | scenario | scenario | self-test group |
| `schema-number-unicode` | 拒绝小数形式的 integer，字符串长度按 Unicode code point 计算 | scenario | scenario | scenario | scenario |
| `call-limit` | 模型和工具调用上限失败关闭 | scenario | scenario | scenario | self-test group |
| `pii-tool-history` | 嵌套工具调用历史被脱敏且不修改输入 | scenario | scenario | scenario | scenario |
| `checkpoint-content` | allowlist 往返保留嵌套 payload 内容 | scenario | scenario | scenario | scenario |
| `capacity-failclosed` | 上下文预算不足时失败关闭，不静默丢弃必需输入 | scenario | scenario | scenario | self-test group |
| `parallel-tools` | 工具按上限并发启动并保持结果顺序 | scenario | scenario | scenario | self-test group |
| `run-state-isolation` | 调用上限状态在并发 run 之间隔离 | scenario | scenario | scenario | self-test group |
| `stream-callback-error` | 流回调失败中止 run，而不是继续完成 | scenario | scenario | scenario | scenario |
| `sse-truncated` | 未完成的 SSE 流被拒绝 | scenario | scenario | scenario | self-test group |
| `sse-half-packet` | SSE 半包失败，不被静默丢弃 | scenario | scenario | scenario | self-test group |

`scenario` 表示为该行为命名的测试。`self-test group` 表示一个 Java self-test 可执行文件覆盖多个场景，因此组通过不能定位到具体场景断言。报告保留这一区别，不把组覆盖当作场景级证据。

## 扩展覆盖

| 场景 | Rust | Fortran | COBOL | Ruby | Elixir | Erlang | C++ | PHP | C# | Lua |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `schema-number-unicode` | scenario | unsupported | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `call-limit` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `pii-tool-history` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `checkpoint-content` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `capacity-failclosed` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `run-state-isolation` | scenario | unsupported | native suite | native suite | native suite | native suite | native suite | native suite | native suite | unsupported |

`native suite` 表示该实现的完整原生测试可执行文件通过；它不是场景隔离断言，因此不能仅凭该单元格定位具体场景失败。其余 Rust/Fortran/PHP/C#/Lua 场景仍为 `unsupported`；报告会显式列出，而不是删除这些语言。

C# 和 PHP 还对 `final-arguments`、`final-name`、`unchanged-single-auth` 和
`initial-denial` 提供原生套件覆盖。COBOL、Ruby、C++、Elixir 和 Erlang 对全部十九个场景提供原生套件覆盖，包括取消、流式回调失败、SSE 截断/半包、并行工具和 run-state isolation。完整的单元格矩阵和逐语言报告见
[行为实验矩阵](behavior-lab-matrix.md)。

## 运行

在仓库根目录，先构建 TypeScript、编译 Java 测试类，并构建 C++ 测试：

```bash
cd language/typescript; npm ci; npm run build; cd ../..
cd language/java; mvn -q -DskipTests test-compile; cd ../..
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build
python scripts/behavior_lab.py --strict --timeout 300
python scripts/behavior_lab.py --strict --timeout 600 --languages go,python,typescript,java,rust,fortran,cobol,ruby,elixir,erlang,cpp,php,csharp,lua,r,c
```

十六语言运行需要 Rust 工具链，以及 `gfortran`、`gnucobol`、`g++`、C/C++ 构建目录、CMake、Ninja、Ruby、Elixir 1.20.4/Erlang OTP 29、PHP 8.4、.NET 8 SDK、R 和 Lua 5.4；Fortran 会构建 pinned RE2 bridge。Fortran/COBOL/Erlang/C++/PHP/C#/Lua/R 原生套件、C `ctest` 套件、Ruby 测试运行器和 Elixir `mix run` 套件在一次报告内缓存，各执行一次。`scripts/cpp_behavior_suite.py` 会在调用 `ctest` 前把 C++ 编译器运行时目录加入 `PATH`。运行前先构建 C 套件：

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build
```

- `--strict`：对四个已接入场景的核心语言，只要出现 `failed`、`skipped`、`not_run` 或 `unsupported` 单元格就失败；其他层级的缺口保留为 `unsupported`。
- `--languages go,python`：只运行指定语言。
- `--timeout 300`：设置单条命令超时。
- `--output-dir build/behavior-lab`：修改报告位置。

每次执行会生成独立目录：

- `build/behavior-lab/<run-id>/report.json`
- `build/behavior-lab/<run-id>/report.md`
- `build/behavior-lab/latest.json`（指向最新报告的指针）

报告记录 run ID、UTC 起止时间、运行前采集的 Git revision 和 dirty 状态、平台、每个场景、所用命令、退出码、耗时，以及有长度限制的 stdout/stderr 尾部。单元格状态为 `passed`、`failed`、`skipped`、`not_run` 或 `unsupported`。旧运行目录不会被覆盖；`latest.json` 只是便利指针。

## 当前证据

2026-10-31 的 Go/Python/TypeScript/Java 十九场景本地运行通过了全部 76 个单元格。commit `7a7b796` 上的 clean-SHA Linux CI 运行通过十六语言集合：262 passed、42 个显式 unsupported、无失败；引用报告时应使用该 [behavior job](https://github.com/axisvela/praxo-core/actions/runs/41296991587/job/124819809721) 及其 artifact。所有 agent-capable 语言和 C 均为 19/19；PHP 为 18/19，因为并行工具不可移植。COBOL 0.3.0 通过原生套件覆盖达到 19/19，其中 parallel-tools 将并发执行委托给调用方提供的批处理调度器。Ruby、C++、Elixir 和 Erlang 0.3.0 也在源码中达到 19/19；行为实验矩阵反映 7a7b796 报告，将在下一次干净 CI 报告后刷新。[行为实验矩阵](behavior-lab-matrix.md) 列出每个单元格以及各语言的已覆盖和未覆盖场景。

## 限制

- 只覆盖十九个选定场景，不覆盖完整 agent 或契约对齐。
- Go 和 Python 使用场景级测试；TypeScript 使用 `node --test` 名称过滤；部分 Java self-test 覆盖多个场景。
- 所有 agent-capable 语言和 C 均为 19/19；COBOL 也通过原生套件达到 19/19，其中 parallel-tools 将并发执行委托给调用方提供的批处理调度器，原生测试验证批处理上限和结果顺序，而不是 OS 线程。Ruby 通过原生线程和原生套件达到 19/19；C++ 通过 std::async 并行工具和原生套件达到 19/19；Elixir 通过 Task.async 并行工具和原生套件达到 19/19；Erlang 通过 spawned-process 并行工具和原生套件达到 19/19。PHP 为 18/19，并行工具因无便携线程模型而不支持。Fortran、Lua 对部分行使用原生套件覆盖，不是场景隔离断言。
- 并行场景使用确定性 barrier，不是吞吐或压力测试。SSE 测试使用本地 fixture，不调用 provider。
- 不覆盖 provider、模型、网络、sandbox、HITL、持久 checkpoint 或效果恢复场景。
- 报告通过不等于安全审查或生产认证。
