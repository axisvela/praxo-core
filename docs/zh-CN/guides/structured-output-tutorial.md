# 多语言 Structured Output

发布包处理器示例将自由文本转换为受校验 JSON。[语言覆盖矩阵](../getting-started/language-coverage.md)
列出三十一种语言的结构化输出源码入口，不代表三十一个等价处理器或已验证应用教程。

五个主要 SDK 提供发布包示例：

- [Python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output)
- [TypeScript](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/structured-output)
- [Java](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/structured-output)
- [C#](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/structured-output)
- [Rust](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/structured-output)

其余 SDK 在 `language/<language>/examples/structured-output` 提供确定性源码示例。Go
参考配方位于 `examples/recipes/structured-output-go`。

处理器示例校验 `title`、`summary` 和 `tags`。源码模式机制检查可能使用更小的 schema，
例如 C 只检查 `name`，不调用模型。Schema 检查通过不是模型到应用集成的证据。

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

## 发布包示例

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

示例安装已发布的 PyPI `praxo-core==0.9.0`。

### TypeScript

```bash
cd language/typescript/examples/structured-output
npm install
npm start -- "Quarterly status: all checks green."
npm test
```

示例安装已发布的 npm `@axisvela/praxo-core@0.8.0`。

### Java

```bash
cd language/java/examples/structured-output
mvn -q compile exec:java -Dexec.args="Quarterly status: all checks green."
mvn -q test
```

示例解析 Maven Central `com.axisvela:praxo-core:0.9.0`。

### C#

```bash
cd language/csharp/examples/structured-output
dotnet run -- "Quarterly status: all checks green."
dotnet run -- --test
```

示例安装已发布的 NuGet `Praxo.Core==0.9.1`。

### Rust

```bash
cd language/rust/examples/structured-output
cargo run
```

确定性运行会验证合法摘要，并拒绝缺少必填字段的输出。示例使用已发布的 crates.io
`praxo-core==0.9.1`。

## Go 参考配方

```bash
cd examples/recipes/structured-output-go
GOWORK=off go test -mod=readonly -run 'Structured|Schema|Arguments|ResponseFormat' -v ./...
```

在仓库根目录运行发布包检查：

```bash
python scripts/test_go_structured_output_recipe.py -v
```

Go 配方还验证非法工具参数在产生效果前被拒绝，以及 `model.ResponseFormat` 携带同一份
schema。

## 源码模式示例

源码模式示例使用仓库内实现，不安装发布包。需要构建 Core 的语言应先完成构建，然后在
仓库根目录运行示例。每个示例会输出对应语言的 `structured output example passed`，
并在合法输出被拒绝或非法输出被接受时以非零状态退出。

| 语言 | 运行命令 |
| --- | --- |
| C | `gcc -std=c11 -I language/c/include language/c/examples/structured-output/main.c language/c/build/libpraxo_core.a -lm -o build/c-structured-output && ./build/c-structured-output` |
| C++ | `g++ -std=c++20 -I language/cpp/include language/cpp/examples/structured-output/main.cpp language/cpp/build/libpraxo_cpp.a -o build/cpp-structured-output && ./build/cpp-structured-output` |
| COBOL | `python language/cobol/examples/structured-output/build.py` |
| D | `dmd -i -Ilanguage/d/source -run language/d/examples/structured-output/structured_output.d` |
| Dart | `dart language/dart/examples/structured-output/structured_output.dart` |
| Delphi / Free Pascal | `fpc -Mobjfpc -Fulanguage/delphi language/delphi/examples/structured-output/structured_output.pas && ./structured_output` |
| Elixir | `elixir -pa language/elixir/build/ebin language/elixir/examples/structured-output/structured_output.exs` |
| Erlang | `escript language/erlang/examples/structured-output/structured_output.escript` |
| Fortran | `python language/fortran/examples/structured-output/run.py` |
| Haskell | `runghc -ilanguage/haskell/src language/haskell/examples/structured-output/structured_output.hs` |
| Julia | `julia language/julia/examples/structured-output/structured_output.jl` |
| Lua | `lua language/lua/examples/structured-output/structured_output.lua` |
| MATLAB / Octave | `octave-cli --path language/matlab-octave-core --path language/matlab/examples/structured-output --eval structured_output_example` |
| Nim | `nim r --path:language/nim/src language/nim/examples/structured-output/structured_output.nim` |
| Objective-C | `clang -fobjc-arc -Ilanguage/objc/src language/objc/examples/structured-output/structured_output.m language/objc/src/PraxoJsonSchema.m language/objc/src/PraxoJSON.m -framework Foundation -o build/objc-structured-output && ./build/objc-structured-output` |
| OCaml | `ocaml language/ocaml/examples/structured-output/structured_output.ml` |
| Perl | `perl language/perl/examples/structured-output/structured_output.pl` |
| PHP | `php language/php/examples/structured-output/structured_output.php` |
| PowerShell | `pwsh -NoProfile -File language/powershell/examples/structured-output/structured_output.ps1` |
| R | `Rscript language/r/examples/structured-output/structured_output.R` |
| Ruby | `ruby -I language/ruby/lib language/ruby/examples/structured-output/structured_output.rb` |
| Swift | `swift run --package-path language/swift praxo-structured-output-example` |
| V | 见表格下方的 V 命令。 |
| Zig | `zig build-exe language/zig/examples/structured-output/structured_output.zig --dep json --dep jsonschema -Mroot=language/zig/examples/structured-output/structured_output.zig -Mjson=language/zig/src/json.zig -Mjsonschema=language/zig/src/jsonschema.zig -femit-bin=build/zig-structured-output && ./build/zig-structured-output` |

Core 构建前置命令：

```bash
# C
cmake -S language/c -B language/c/build && cmake --build language/c/build

# C++
cmake -S language/cpp -B language/cpp/build && cmake --build language/cpp/build

# Elixir
mkdir -p language/elixir/build/ebin
elixirc -o language/elixir/build/ebin language/elixir/lib/praxo/*.ex language/elixir/lib/praxo/adapters/*.ex
```

```bash
# V
v -path "language/v|@vlib|@vmodules" language/v/examples/structured-output/structured_output.v
```

Octave 通过共享的 `language/matlab-octave-core` 复用 MATLAB 示例。

## Python 原型演练

这是主要 SDK 的完整首个原型：将一段自由文本转换为受校验 JSON，并在模型缺少必填字段时
失败关闭。

1. 创建应用目录并安装发布包：

```bash
python -m venv .venv
.venv/bin/python -m pip install "praxo-core==0.9.0"
```

2. 从
   [`language/python/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output)
   复制已测试的 schema 和 agent 配置。保留显式策略 allowlist 与 `StructuredOutput`
   middleware。

3. 先运行确定性模型：

```bash
.venv/bin/python summarize.py "Quarterly status: all checks green."
```

4. 运行确定性拒绝测试。缺少 `summary` 或 `tags` 的响应必须抛错，而不是返回部分 JSON：

```bash
.venv/bin/python -m unittest test_summarize.py -v
```

5. 只有在确定性路径通过后，才把 fixture 模型替换为 OpenAI-compatible adapter。保持同一份
   schema 和策略；切换到真实端点时不要移除校验层。

6. 记录包版本、端点类型、模型名、schema 版本和命令输出。这是本地原型，不是生产服务：
   身份、持久存储、重试、效果验证和隔离仍由应用负责。

## TypeScript 原型演练

1. 创建应用目录并安装发布包：

```bash
npm init -y
npm install --save-exact @axisvela/praxo-core@0.8.0
```

2. 从
   [`language/typescript/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/structured-output)
   复制 schema、fixture 模型、策略和 `StructuredOutput` 配置。

3. 运行确定性原型：

```bash
npm start -- "Quarterly status: all checks green."
npm test
```

4. 测试必须拒绝缺少 `summary` 或 `tags` 的响应；没有 schema 校验的解析对象不算通过。

5. 只有在确定性测试通过后，才把 fixture 模型替换为 `OpenAICompatibleModel`。保持同一份
   schema、allowlist 和策略，并记录包版本、端点类型、模型名和命令输出。

## 其他原型路径

先检查各语言 `examples/structured-output` 的实际 schema 和程序，构建或安装其依赖的
Core，再运行接受/拒绝断言。Schema-only 机制还需要模型和应用集成才能成为处理器，
单独增加 Provider Adapter 不等于完成集成。

Java、C# 分别提供确定性测试模式和真实端点运行命令；Rust 默认示例使用确定性模型。
Go 配方同时验证结构化输出和工具参数。
Ruby、PHP、Elixir、Lua、C、C++、Fortran、COBOL、Erlang、Dart、Perl、Julia、Swift、
Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB、Octave 和 Objective-C
的源码示例在无 provider 端点时展示相同的接受/拒绝行为。

对每种语言记录包或源码 revision、端点类型、模型名、schema 版本、命令和输出。身份、
持久存储、重试、效果验证和隔离仍保留在应用中。

## 真实端点

发布包示例使用 OpenAI-compatible 端点：

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

未提供 provider adapter 的源码示例只验证 schema。只有把 provider adapter 接到同一模型
接缝后，才能声称完成真实端点路径。

## 示例证明了什么

- 有发布包示例的语言从 registry 安装包；
- 支持真实端点的示例从环境变量配置模型 Adapter；
- 处理器示例按各自 schema 校验最终 JSON；
- fixture-model 检查无需真实端点即可验证对应集成；
- schema-only 源码示例只检查自己的较小校验用例。

它们不证明模型质量、schema 完整性、Provider 原生结构化输出支持或生产行为。即使
Provider 原生支持结构化输出，应用仍应保留最终 schema 校验。

## 相关文档

- [示例目录](../getting-started/examples.md)
- [语言覆盖](../getting-started/language-coverage.md)
- [真实模型 Golden Path](../getting-started/live-model-golden-path.md)
- [应用嵌入清单](application-integration-checklist.md)
- [消费者测试模板](consumer-test-template.md)
