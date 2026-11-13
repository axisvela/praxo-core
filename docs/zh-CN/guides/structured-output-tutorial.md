# 多语言 Structured Output

本教程使用 `StructuredOutput` 将自由文本转换为受校验 JSON。四种发布包示例使用同一份
schema：

- [Python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output)
- [TypeScript](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/structured-output)
- [Java](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/structured-output)
- [C#](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/structured-output)

每个示例都会在返回模型输出前校验 `title`、`summary` 和 `tags`。非法输出会失败，
不会返回畸形数据。

## Schema

```json
{
  "type": "object",
  "required": ["title", "summary", "tags"],
  "properties": {
    "title": { "type": "string" },
    "summary": { "type": "string" },
    "tags": { "type": "array", "items": { "type": "string" } }
  }
}
```

## 按语言运行

### Python

```bash
cd language/python/examples/structured-output
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python summarize.py "Quarterly status: all checks green."
```

确定性测试：

```bash
.venv/bin/python -m unittest test_summarize.py -v
```

### TypeScript

```bash
cd language/typescript/examples/structured-output
npm install
npm start -- "Quarterly status: all checks green."
npm test
```

### Java

```bash
cd language/java/examples/structured-output
mvn -q compile exec:java -Dexec.args="Quarterly status: all checks green."
mvn -q test
```

### C#

```bash
cd language/csharp/examples/structured-output
dotnet run -- "Quarterly status: all checks green."
dotnet run -- --test
```

## 真实端点

运行命令使用 OpenAI-compatible 端点：

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
# export PRAXO_API_KEY=...   # 仅托管端点需要
```

PowerShell：

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "llama3.2"
```

## 示例证明了什么

- 包从 registry 安装；
- 模型 Adapter 从环境变量配置；
- `StructuredOutput` 按 schema 校验最终 JSON；
- fake-model 测试无需真实端点即可验证集成。

它们不证明模型质量、schema 完整性、Provider 原生结构化输出支持或生产行为。即使
Provider 原生支持结构化输出，应用仍应保留最终 schema 校验。

## 相关文档

- [示例目录](../getting-started/examples.md)
- [真实模型 Golden Path](../getting-started/live-model-golden-path.md)
- [应用嵌入清单](application-integration-checklist.md)
- [消费者测试模板](consumer-test-template.md)
