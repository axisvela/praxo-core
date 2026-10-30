# 行为实验

**状态：** 证据工具，2026-10-30。该实验不是稳定的公开 API。

行为实验在 Go、Python、TypeScript 和 Java 中运行具名 agent 场景，并生成一份对比报告。它回答的问题比[兼容性实验](compatibility-lab.md)更窄：当通过各实现自己的测试套件执行时，它们是否对授权、middleware 生命周期和取消做出相同决策？

它不证明完整功能对齐、provider 行为、真实服务集成、生产就绪或安全性。报告通过只比较所列场景。

## 范围

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

`scenario` 表示为该行为命名的测试。`self-test group` 表示一个 Java self-test 可执行文件覆盖多个场景，因此组通过不能定位到具体场景断言。报告保留这一区别，不把组覆盖当作场景级证据。

Rust、Fortran、COBOL 及其余实现不在首批范围内。只有当它们提供等价的 agent 生命周期 hook 和具名行为测试后才应加入。

## 运行

在仓库根目录，先构建 TypeScript 并编译 Java 测试类：

```bash
cd language/typescript; npm ci; npm run build; cd ../..
cd language/java; mvn -q -DskipTests test-compile; cd ../..
python scripts/behavior_lab.py --strict --timeout 300
```

- `--strict`：只要出现 `failed`、`skipped`、`not_run` 或 `unsupported` 单元格就失败。
- `--languages go,python`：只运行指定语言。
- `--timeout 300`：设置单条命令超时。
- `--output-dir build/behavior-lab`：修改报告位置。

每次执行会生成独立目录：

- `build/behavior-lab/<run-id>/report.json`
- `build/behavior-lab/<run-id>/report.md`
- `build/behavior-lab/latest.json`（指向最新报告的指针）

报告记录 run ID、UTC 起止时间、运行前采集的 Git revision 和 dirty 状态、平台、每个场景、所用命令、退出码、耗时，以及有长度限制的 stdout/stderr 尾部。单元格状态为 `passed`、`failed`、`skipped`、`not_run` 或 `unsupported`。旧运行目录不会被覆盖；`latest.json` 只是便利指针。

## 当前证据

2026-10-30 的四语言本地运行通过了全部 36 个单元格。该运行所在工作区包含尚未提交的证据工具改动，因此不是 clean-SHA 记录。commit `54293fd` 上的首次 clean-SHA Linux CI 运行同样通过了全部 36 个单元格；引用行为报告作为证据时，应使用该 [behavior job](https://github.com/axisvela/praxo-core/actions/runs/41051293617/job/124047717624) 及其 artifact。

## 限制

- 只覆盖九个选定场景，不覆盖完整 agent 或契约对齐。
- Go 和 Python 使用场景级测试；TypeScript 使用 `node --test` 名称过滤；Java 使用组 self-test。
- 不覆盖 provider、模型、网络、sandbox、HITL、checkpoint 或效果恢复场景。
- 报告通过不等于安全审查或生产认证。
