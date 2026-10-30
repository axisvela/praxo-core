# 兼容性实验

**状态：** 证据工具，2026-10-30。该实验不是稳定的公开 API。

兼容性实验运行选定语言实现现有的确定性 Core 一致性检查，并生成可复现报告。它只回答一个很窄的问题：这些实现在当前机器和工具链上，声明的向量组和 parity 检查是否通过？

它不证明与 Go 的完整功能对齐、provider 行为、真实服务集成、生产就绪或安全性。这些不同层次的主张请参见[语言支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)和[验证证据](../project/verification-evidence.md)。

## 范围

首批范围是 Python、TypeScript、Java 和 Rust。每个条目运行该实现自己的 conformance 入口：

| 语言 | 命令 |
| --- | --- |
| Python | `python conformance/run.py` |
| TypeScript | `npm run build`，然后 `npm run conformance` |
| Java | `mvn -q -DskipTests package`，然后运行 Java conformance runner |
| Rust | `cargo run --quiet --bin conformance` |

实验覆盖共享契约向量，以及该实现已有的 parity 检查。它不启动模型、不调用 provider、不使用凭证，也不运行真实 workspace provider。

## 运行

在仓库根目录执行：

```bash
python scripts/compatibility_lab.py --install --strict
```

- `--install`：在执行构建前运行语言准备步骤（TypeScript 使用 `npm ci`）。
- `--strict`：将跳过的语言或工具链视为失败。
- `--languages python,java`：只运行指定语言。
- `--timeout 300`：设置单条命令超时。

命令会生成：

- `build/compatibility-lab/report.json`
- `build/compatibility-lab/report.md`

报告记录 Git revision 和 dirty 状态、平台、工具链版本、每条命令、退出码、耗时，以及有长度限制的 stdout/stderr 尾部。失败和跳过会被保留，不会被后续成功运行覆盖。

## 当前证据

2026-10-30 的首次本地运行中，四个选定实现全部通过：

| 语言 | 结果 | 本地使用的工具链 |
| --- | --- | --- |
| Python | passed | Python 3.14.6 |
| TypeScript | passed | Node.js 24.18.0 |
| Java | passed | OpenJDK 21.0.8 |
| Rust | passed | Cargo 1.96.0 |

该次运行所在工作区包含尚未提交的证据工具改动，因此不是 clean-SHA 发布记录。将其作为可复现 CI 证据引用前，应在合并后的 revision 上重新运行。

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
