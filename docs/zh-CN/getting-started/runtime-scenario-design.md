# 语言适配教程设计

这些是教程设计，不是新增 Core 能力，也不扩充现有 100 个场景 ID。
按语言生态、常见用法与宿主形态选择主入口，保留旧教程与已发布链接。

## 场景选择

**CI 更新：2026-11-25。** 下列九条路径在 `dfdfd558`、
[运行 45537631891](https://github.com/axisvela/praxo-core/actions/runs/45537631891) 的教程作业均通过。
末列保留最初本地快照，“远端 CI 未核验”只描述当时，不是当前 CI 状态。
托管执行不证明真实 Provider、硬件、生产或独立采用。这些有界路径是
[参考应用组合](../project/delivery-history.md)的可复用输入，不代替完整宿主集成。

| 语言 | 主教程方向 | 关联目标 | 生态依据 | 必须真实执行 | 最初本地快照（CI 以上述更新为准） |
| --- | --- | --- | --- | --- | --- |
| V | [本地配置与发布预检](https://github.com/axisvela/praxo-core/tree/main/language/v/Tutorial/release-preflight) | SE-01 | 编译型 CLI、C 互操作；探索性生态，不代表行业主流 | 解析临时配置、拒绝缺失字段、草拟修正；不部署 | 本地 V 测试通过；远端 CI 未核验 |
| D | [数据导入流水线诊断](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/data-pipeline) | SC-06 | 原生数据处理、标准库 ranges/algorithms 与 C 互操作 | 解析记录、计算错误统计、基于结果选择复核动作 | 本地 DMD 测试通过；远端 CI 未核验 |
| Haskell | [业务规则 DSL 校验](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/rule-dsl) | SE-05 | 类型化 AST、解析库、纯函数求值与属性测试 | 解析规则、检测冲突、返回反例；不发布规则 | 本地 GHC 测试通过；远端 CI 未核验 |
| OCaml | [静态分析诊断复核](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/static-diagnostics) | SE-05 | 编译器、类型化语法树、分析器生态 | 解析诊断或小型 AST，按源码位置执行规则 | 本地 OCaml 测试通过；远端 CI 未核验 |
| Erlang | [OTP 服务恢复复核](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial/otp-recovery) | SE-06 | 电信、消息系统、进程隔离与监督树 | 启动监督树、注入子进程故障、观察恢复后草拟建议 | 本地 OTP 测试通过；远端 CI 未核验 |
| Julia | [有约束能源调度复核](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/dispatch-review) | IN-04 | 数值计算；当前使用原生有界枚举，尚未使用 JuMP | 求解约束模型、报告可行性与目标值；不发电网指令 | 本地 Julia 测试通过；远端 CI 未核验 |
| Octave | [振动信号巡检复核](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/vibration-review) | IN-01 | 矩阵、FFT、MATLAB 风格工程分析 | 比较正常/异常样本的 FFT/RMS；不预测故障 | 本地 Octave 测试通过；远端 CI 未核验 |
| COBOL | [日终对账异常复核](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) | FC-03 | 十进制业务记录与银行/保险批处理 | COBOL 计算差异、复核异常记录；不改账 | 本地 GnuCOBOL 测试通过；远端 CI 未核验；仅固定宽度 fixture |
| Zig | [C ABI 宿主健康诊断组件](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) | IN-01 | 显式分配器、原生组件、C ABI | 读取函数表状态、执行固定分配预算与释放；不控制硬件 | 本地 Zig 测试通过；远端 CI 未核验；固定预算 scratch 分配，不是通用分配策略 |

关联目标是发现线索，不是完整实现或通用推荐。V、Zig 是宿主/工具链选择，不能宣称
已广泛用于行业系统。Julia 自写枚举不算 JuMP 验证；Erlang escript 不算监督树验证。

## 教学契约

每个教程先做真实的解析、计算或运行时操作，再通过 Core 工具返回结果。
确定性 Agent 必须根据工具结果选择后续动作，而非无条件返回成功草案。
无凭据测试覆盖成功、格式错误或不可行输入、副作用前范围拒绝，以及依赖失败后无草拟。
真实模型可复用相同工具做可选验证，证据单独记录。

## 实现顺序

先实现 D 数据解析，再依次处理 V、Haskell、OCaml、Erlang、Julia 和 Octave。
COBOL、Zig 增强现有入口，不另复制宿主。设计通过不代表运行通过，发布前须执行教程自身
测试；本地工具链限制不能当作产品能力。

本设计链接到教程计划和各语言介绍，完成的源码入口接入生成目录和 CI。
业务工具不扩大 Core API，不修改规范 wire 契约。
