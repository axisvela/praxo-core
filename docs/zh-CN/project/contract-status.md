# 契约与证据状态

**状态：** 公开规划参考，2026-11-05。本页定义路线图使用的状态词，并记录主要契约领域的
当前状态。它不是发布排期，也不扩大任何 API 或 Profile。

## 状态词

| 状态 | 含义 | 最低证据 |
| --- | --- | --- |
| 已实现（Implemented） | 规范契约或公开 API 已在 Go 参考实现中存在并有自动测试 | 源码、适用时的 API 快照和测试 |
| 已验证（Verified） | 证据绑定到精确提交、产物和日期 | 该 revision 的运行或评审记录 |
| 提案（Proposed） | 仅设计或验收标准 | 设计文档；没有 API、Wire 或 Profile 保证 |
| 实验（Experimental） | 已有明确消费者可用，但可能变化，不在稳定承诺内 | 消费者和写明限制的测试 |
| 未运行 / 未开始（Not run / Not started） | 尚无结果或实现证据 | 无；不得写成通过 |

`已验证` 是限定范围的证据。后续仅文档提交不会扩展它。集成测试不证明采用，一致性测试
不证明生产安全或运行就绪。

这些词描述契约与证据状态，不替代 [`spec/parity.md`](https://github.com/axisvela/praxo-core/blob/main/spec/parity.md)
中的 `planned`、`partial`、`parity`、`n/a` 覆盖标签，也不替代[语言总表](../languages/matrix.md)
中的支持等级。

## 当前矩阵

| 领域 | 状态 | 范围与限制 |
| --- | --- | --- |
| Go 参考 API 与共享 Wire 产物（事件、错误、JSON Schema 子集、插件） | 已实现；按发布 revision 验证 | `spec/` 中的规范文件与向量；不证明真实 provider 或产品部署 |
| Tool、Model、Checkpoint Wire 描述 | 计划中 | `spec/README.md` 仍列为计划项；不得作为稳定契约引用 |
| Go、Python、TypeScript、Java 独立消费者 | 已实现；在各自标注 revision 验证 | 发布包安装、构建与确定性允许/拒绝检查；属于集成证据，不是采用证据 |
| 受治理执行 Profile | 提案 | 设计定义了验收标准；尚未实现通用 Core Profile |
| 编程 Agent 采用实验 | 未运行 | 没有发现、选型、首次通过、修复成本或留存数据 |
| 具身集成 Profile | 未开始 | 需要明确消费者、中间件选择和仿真场景 |
| 语言一致性、功能覆盖与运行证据 | 参见 `spec/parity.md`、语言总表与 Behavior Lab | 分开的维度；源码标签不提供运行证据 |

## 引用证据

引用状态时写明 revision、产物和结果，并说明证据属于哪一层：

1. 契约一致性；
2. 已发布包消费者检查；
3. 真实本地服务或 provider 集成；
4. 硬件、仿真或生产观察。

不得用一层暗示另一层。采用实验中明确指定框架属于指定集成证据，不是自由选型证据。
正确排除不适用框架是成功的选型决策，不是采用失败。

共享 Wire 变更分类见 [`spec/README.md`](https://github.com/axisvela/praxo-core/blob/main/spec/README.md)
规范规则与[兼容政策](compatibility-policy.md)。可选 Profile 不能绕过 Wire、parity 或
conformance 审查。
