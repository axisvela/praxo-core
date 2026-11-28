# 行为实验

**状态：** 证据工具，2026-11-01。该实验不是稳定的公开 API。
?????????????????? agent ?????????????wired ??? Go?Python?TypeScript?Java?Rust?R?C#?C?PHP?Fortran?COBOL?Ruby?Elixir?Erlang?C++?Lua?????????????????????????[?????](compatibility-lab.md)?????????????????????????????????????????????????????run ?????PII?checkpoint??????????????

???????????provider ???????????????????????????????
它不证明完整功能对齐、provider 行为、真实服务集成、生产就绪或安全性。报告通过只比较所列场景。

## ??????

?????????????????????

- ????????????????????????? Go?Python?TypeScript?Java?
- ?????????????????????????????????
- unsupported???????????????????

??? wired ???????????????COBOL?Lua?PHP?Fortran ??????????????????????????[??](behavior-lab-matrix.md)?

## 范围

下表展示四个原始核心实现的场景级证据。Rust、R、C# 以及其余 wired 语言见[矩阵](behavior-lab-matrix.md)。

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
| `hitl-decision` | 中断调用执行 approve、edit、reject、respond 决策 | scenario | scenario | scenario | self-test group |

`scenario` 表示为该行为命名的测试。`self-test group` 表示一个 Java self-test 可执行文件覆盖多个场景，因此组通过不能定位到具体场景断言。报告保留这一区别，不把组覆盖当作场景级证据。

### Go 参考通知完整性

`v2.7.0` 调整 Go 参考实现：批次中一个工具失败后，仍为每个已执行工具发送 task-end 流与
`OnToolResult`，同时批次仍返回首个错误。这不在上述二十个场景内，也不对其他实现作声明。
Python、TypeScript、Java 与其他 wired 语言没有相同的 `OnToolResult` 和 task-end 流表面；其并行
结果收尾路径返回首个错误，跨语言通知完整性仍未验证。参见
[Execution Correctness Suite](../project/planning/execution-correctness-model.md) 的 EC-01。

## 扩展覆盖

| 场景 | Rust | Fortran | COBOL | Ruby | Elixir | Erlang | C++ | PHP | C# | Lua |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `schema-number-unicode` | scenario | unsupported | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `call-limit` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `pii-tool-history` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `checkpoint-content` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `capacity-failclosed` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `run-state-isolation` | scenario | unsupported | native suite | native suite | native suite | native suite | native suite | native suite | native suite | unsupported |

`native suite` 表示该实现的完整原生测试可执行文件通过；它不是场景隔离断言，因此不能仅凭该单元格定位具体场景失败。所有已接入语言均覆盖二十个场景；报告仍会显式列出每个单元格。

C# 和 PHP 还对 `final-arguments`、`final-name`、`unchanged-single-auth` 和
`initial-denial` 提供原生套件覆盖。C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++ 和 Lua 对全部二十个场景提供原生套件覆盖，包括取消、流式回调失败、SSE 截断/半包、并行工具和 run-state isolation。完整的单元格矩阵和逐语言报告见
[行为实验矩阵](behavior-lab-matrix.md)。

## 运行

在仓库根目录，先构建 TypeScript、编译 Java 测试类，并构建 C++ 测试：

```bash
cd language/typescript; npm ci; npm run build; cd ../..
cd language/java; mvn -q -DskipTests test-compile; cd ../..
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build
python -m scripts.labs.behavior_lab --strict --timeout 300
python -m scripts.labs.behavior_lab --strict --timeout 600 --languages go,python,typescript,java,rust,fortran,cobol,ruby,elixir,erlang,cpp,php,csharp,lua,r,c
```

十六语言运行需要 Rust 工具链，以及 `gfortran`、`gnucobol`、`g++`、C/C++ 构建目录、CMake、Ninja、Ruby、Elixir 1.20.4/Erlang OTP 29、PHP 8.4、.NET 8 SDK、R 和 Lua 5.4；Fortran 会构建 pinned RE2 bridge。Fortran/COBOL/Erlang/C++/PHP/C#/Lua/R 原生套件、C `ctest` 套件、Ruby 测试运行器和 Elixir `mix run` 套件在一次报告内缓存，各执行一次。`scripts/labs/cpp_behavior_suite.py` 会在调用 `ctest` 前把 C++ 编译器运行时目录加入 `PATH`。运行前先构建 C 套件：

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

Ruby、C++、Elixir、Erlang、Lua、PHP、Fortran、C 以及其他 wired SDK 也达到 20/20；全部十六个实现都包含 HITL decision 场景。

## 限制

- 只覆盖二十个选定场景，不覆盖完整 agent 或契约对齐。
- Go 和 Python 使用场景级测试；TypeScript 使用 `node --test` 名称过滤；部分 Java self-test 覆盖多个场景。
所有 wired 语言与 C 均为 20/20；COBOL 也通过原生套件达到 20/20，其中 parallel-tools 将并发执行委托给调用方提供的批处理调度器，原生测试验证批处理上限和结果顺序，而不是 OS 线程。Ruby 通过原生线程和原生套件达到 20/20；C++ 通过 std::async 并行工具和原生套件达到 20/20；Elixir 通过 Task.async 并行工具和原生套件达到 20/20；Erlang 通过 spawned-process 并行工具和原生套件达到 20/20；Lua 通过调用方提供的协作批处理工具和原生套件达到 20/20；PHP 通过 batchToolInvoker 中的 Fiber 和原生套件达到 20/20；Fortran 通过调用方提供的并行批处理回调达到 20/20。以上均为套件级覆盖，不是场景隔离断言。
- 并行场景使用确定性 barrier，不是吞吐或压力测试。SSE 测试使用本地 fixture，不调用 provider。
- 不覆盖 provider、模型、网络、sandbox、持久 checkpoint 或效果恢复场景。
- 报告通过不等于安全审查或生产认证。
