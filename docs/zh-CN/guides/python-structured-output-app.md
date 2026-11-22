# Python 结构化输出应用

本教程构建一个小型批处理应用：把文本文件转换为受校验 JSON，将模型拒绝的输出单独
记录，并在续跑时跳过已成功的输入。应用使用 Python Core 和 `StructuredOutput`
Middleware。

示例位于
[`language/python/examples/structured-output-app`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output-app)。
它是应用形态路径：输入目录、结果文件、错误文件、确定性 fixture 模型、可选真实模型
和续跑模式。

## 你将构建什么

对输入目录中的每个 `*.txt` 文件，应用会：

1. 请求模型返回包含 `title`、`summary` 和 `tags` 的 JSON；
2. 按 Schema 校验响应；
3. 把通过校验的记录追加到 `out/results.jsonl`；
4. 把被拒绝的响应追加到 `out/errors.jsonl`；
5. 使用 `--resume` 时跳过已经成功的输入。

被拒绝的模型响应不会变成结果数据。失败记录包含源文件和错误类型。

## 设置

```bash
cd language/python/examples/structured-output-app
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

如果使用源码检出而不安装发布包，把 `PYTHONPATH` 指向仓库的 Python Core：

```bash
export PYTHONPATH=language/python
```

## 运行确定性应用

创建两个输入：

```bash
mkdir -p inputs
printf 'Quarterly status: all checks green.\n' > inputs/quarterly.txt
printf 'invalid payload: the model omits required fields\n' > inputs/invalid.txt
```

运行 fixture 模型：

```bash
.venv/bin/python app.py --input-dir inputs
```

预期摘要：

```text
processed=1 skipped=0 failed=1
```

`out/results.jsonl` 包含一条通过校验的记录：

```json
{"result":{"summary":"Quarterly status: all checks green.","tags":["triage"],"title":"Quarterly status: all checks green."},"source":"quarterly.txt"}
```

`out/errors.jsonl` 记录无效响应，而不是接受它：

```json
{"detail":"agent: structured output validation failed: schema: $.summary: required field missing, $.tags: required field missing","error":"StructuredOutputError","source":"invalid.txt"}
```

当输入包含 `invalid` 时，fixture 模型会故意返回不完整对象，因此无需真实端点即可
执行失败路径。

## 续跑

运行同一命令并加上 `--resume`：

```bash
.venv/bin/python app.py --input-dir inputs --resume
```

预期摘要：

```text
processed=0 skipped=1 failed=1
```

成功输入被跳过；失败输入因为没有结果记录而重试。续跑是工作流便利功能，不是
exactly-once 或效果账本保证。

## 使用真实模型

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
.venv/bin/python app.py --input-dir inputs --live
```

通过应用环境提供凭据。不要把 Provider Key 放进输入目录或提交到仓库。

## 失败处理

- Schema 校验错误写入 `out/errors.jsonl`，不会写成结果。
- 任一输入失败时进程以非零退出，方便调度系统发现。
- 失败输入会在下一次 `--resume` 时重试。
- Transport 失败也记录为失败，但不证明远端效果是否发生。重试有副作用工具前，
  应用需要增加效果对账。

## 已记录运行

2026-11-22 在源码检出中设置 `PYTHONPATH=language/python` 运行确定性路径：

```text
processed=1 skipped=0 failed=1
processed=0 skipped=1 failed=1
```

第一次运行写入一条结果和一条错误；续跑跳过成功项并重试失败项。这是维护者运行的
示例集成证据，不是外部消费者或生产部署。

## 边界

- Fixture 模型证明应用接线，不证明模型质量。
- JSON-lines 文件是教学记录，不是数据库、队列或 Lease。
- Schema 校验证明返回对象符合声明的子集 Schema，不证明模型内容真实。
- 身份、租户、保留、隔离和效果对账仍由应用负责。

## 下一步

- 用应用自有 Provider Adapter 替换 Fixture 模型。
- 多 Worker 处理时增加真实 Store 或队列。
- 接受不可信输入前增加认证和租户隔离。
- 把[消费者测试模板](consumer-test-template.md)应用到应用仓库，并记录准确的包版本。
