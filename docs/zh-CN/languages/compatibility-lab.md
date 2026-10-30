# 兼容性实验

**状态：** 证据工具，2026-10-30。该实验不是稳定的公开 API。

兼容性实验运行选定语言实现现有的确定性 Core 一致性检查，并生成可复现报告。它只回答一个很窄的问题：这些实现在当前机器和工具链上，声明的向量组和 parity 检查是否通过？

它不证明与 Go 的完整功能对齐、provider 行为、真实服务集成、生产就绪或安全性。这些不同层次的主张请参见[语言支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)和[验证证据](../project/verification-evidence.md)。

## 范围

首批范围是 Python、TypeScript、Java 和 Rust。Fortran 和 COBOL 是第二批；Linux CI 运行全部六种语言。每个条目运行该实现自己的 conformance 入口：

| 语言 | 命令 |
| --- | --- |
| Python | `conformance/run.py`、`api-snapshot.py --check`、`api-signatures.py --check` |
| TypeScript | `npm run build`、`npm run api:check`、`npm run conformance` |
| Java | `mvn -q -DskipTests package`、`ApiSnapshot --check`、conformance runner |
| Rust | `cargo run --quiet --bin conformance`、`api-snapshot.py --check` |
| Fortran | `run-tests.py`（原生测试、向量、API 快照） |
| COBOL | `run-tests.py`（原生测试、向量、API 快照） |

实验覆盖共享契约向量、API 快照或签名，以及该实现已有的 parity 检查。它不启动模型、不调用 provider、不使用凭证，也不运行真实 workspace provider。

## 运行

在仓库根目录执行：

```bash
python scripts/compatibility_lab.py --install --strict
```

- `--install`：在执行构建前运行语言准备步骤（TypeScript 使用 `npm ci`）。
- `--strict`：将跳过的语言或工具链视为失败。
- `--languages python,java`：只运行指定语言。
- `--languages python,typescript,java,rust,fortran,cobol`：运行完整 Linux CI 集合。
- `--timeout 300`：设置单条命令超时。

每次执行会生成独立目录：

- `build/compatibility-lab/<run-id>/report.json`
- `build/compatibility-lab/<run-id>/report.md`
- `build/compatibility-lab/latest.json`（指向最新报告的指针）

报告记录 run ID、UTC 起止时间、运行前采集的 Git revision 和 dirty 状态、平台、工具链版本、每条命令、退出码、耗时，以及有长度限制的 stdout/stderr 尾部。前序失败后未执行的命令标为 `not_run`，并分别统计语言和命令数量。旧运行目录不会被覆盖；`latest.json` 只是便利指针，本身不是证据。

## 当前证据

2026-10-30 的本地运行中，前四个实现全部通过；后续本地运行也通过了 Fortran。COBOL 由 Linux CI 覆盖，因为本地缺少 GnuCOBOL：

| 语言 | 结果 | 工具链 |
| --- | --- | --- |
| Python | passed | Python 3.14.6 |
| TypeScript | passed | Node.js 24.18.0 |
| Java | passed | OpenJDK 21.0.8 |
| Rust | passed | Cargo 1.96.0 |
| Fortran | passed | GNU Fortran 16.2.0 |
| COBOL | passed | GNU COBOL 2.0.0（本地）和 Linux CI |

首次本地运行所在工作区包含尚未提交的证据工具改动，因此不是 clean-SHA 发布记录。COBOL 已在本地和 Linux CI job 中通过。引用完整六语言集合时，应使用 CI artifact 和合并后的 revision。

## 增加语言

在 `scripts/compatibility_lab.py` 中增加语言定义，至少包含：

- 语言目录中可执行的 conformance 入口；
- 工具链版本命令；
- 必要的构建/准备命令；
- 稳定的工作目录。

该语言必须已经具有已发布或已声明范围的 conformance runner。不要仅仅为了增加数量而添加语言。新条目应按语言矩阵相同的契约、parity 和证据分离方式评审。

## 限制

- 仅覆盖契约一致性，不覆盖功能覆盖度或运行证据。
- 每次运行只覆盖一个平台和一组工具链。
- 不覆盖 provider、模型、网络、sandbox、HITL、checkpoint 或效果恢复场景。
- 报告通过不等于安全审查或生产认证。
