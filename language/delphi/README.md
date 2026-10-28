# PRAXO-CORE for Delphi and Free Pascal

Native Core implementation with source tag `delphi/v0.2.0`. It passes all eleven
vector groups and includes the native agent loop plus memory, event, checkpoint,
policy, context, and middleware helpers. It does not call Go or another language
SDK; there is no model provider, process bridge, or plugin host.

Local validation uses Free Pascal 3.2.2 on Windows i386. It does not establish
commercial Delphi compiler compatibility, Linux/macOS support, package-registry
publication, production readiness, or a delivery date. The CI recipe targets
Free Pascal on Ubuntu.

## Build and Test

With Free Pascal and Python 3.10 or newer, from the repository root:

```bash
python language/delphi/run-tests.py
python language/delphi/api-snapshot.py --check
```

Set `FPC` or pass `--compiler /path/to/fpc` to select the compiler. Python only
launches the native build and validates source API/parity metadata. The test
programs and implementation run under Free Pascal. The runner covers all eleven
shared vector groups and verifies the contract version before running them.
See [SETUP.md](SETUP.md) for prerequisites and individual test commands.

To build manually from `language/delphi/`:

```bash
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild praxo.pas
fpc -Mobjfpc -Scghi -O2 -Fu. -Futests -FEbuild tests/praxo_tests.lpr
./build/praxo_tests ../../spec
fpc -Mobjfpc -Scghi -O2 -Fu. -Futests -FEbuild tests/agent_tests.lpr
./build/agent_tests ../../spec
```

## API

Add `language/delphi` to the compiler unit path and use:

```pascal
var
  data: TJSONData;
  call: TPraxoCall;
begin
  data := PraxoParseJSON('{"name":"echo","input":{"text":"hi"}}');
  try
    if PraxoParseToolCall(PraxoEncodeJSON(data), call) then
      Writeln(call.Name);
  finally
    data.Free;
  end;
end;
```

Public declarations are inventoried in [`api/0.1.0.txt`](api/0.1.0.txt).
The JSON node type is Free Pascal's `TJSONData` (`fpjson`), so consumers already
using `fpjson` can inspect results directly. `TPraxoCall.Input` is caller-owned.
`PraxoValidateManifest` returns an owned `TJSONObject` on success.

The separate `praxo_agent` unit provides `PraxoRunAgent` and an abstract
`TPraxoAgentHost`. Implement `Generate`, `Invoke`, and `Emit` to connect a model,
tools, and an event sink. `Generate` receives a borrowed message array and must
return an owned object with a string `content`, optional integer `inputTokens`
and `outputTokens`, and optional `toolCalls` array containing objects with
string `id`, nonempty string `name`, and object `arguments`. `Invoke` receives
borrowed arguments and returns an owned JSON value. The loop frees returned
objects and values; callbacks must not retain or mutate borrowed data. Tool
results are serialized as JSON in subsequent tool messages. Host exceptions
propagate, with a best-effort `run.failed` event. Budget and malformed response
errors use `EPraxoAgent.Code`; these local validation codes are not wire codes.
Nonpositive `MaxSteps` defaults to eight and nonpositive `MaxTokens` is unlimited.

## Current Limits

- The verified target is Free Pascal 3.2.2 Windows i386. Other FPC targets and
  the proprietary Delphi compiler require separate testing.
- JSON input and output are bounded to 1,048,576 characters and nesting to 64.
  Tool-call input is bounded to 262,144 characters.
- `fpjson` is used for structure, but Unicode escapes are expanded before parsing
  to preserve supplementary code points on FPC 3.2.2. Strings are represented as
  UTF-8 on the verified Windows target; callers should use `UTF8String` for
  lossless non-ASCII data. The supplementary-code-point round-trip test is
  Windows-only; Linux CI currently covers the shared wire vectors but not that
  specific round-trip assertion.
- Numbers are finite doubles; large integers and exact decimal spellings may lose
  precision. Nonfinite values, malformed UTF-8, invalid escapes, duplicate
  manifest fields, and trailing JSON are rejected.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. DSML, invoke, todo, and skill-install formats are not implemented.
  Generated call IDs are not provided; governance metadata is returned in
  `TPraxoCall.Metadata`. Markup stripping is not an authorization control.
- Schema patterns accept a bounded anchored ASCII subset, not full RE2.
  Unsupported patterns raise `EPraxoSchema`. JSON Schema behavior follows the
  documented subset, including zero bounds treated as unset and ignored unknown
  keywords.
- Manifest checks validate declarations only. They do not verify signatures,
  establish trust, execute plugins, or enforce OS sandboxing. Duplicate-field
  rejection is stricter than the Go JSON decoder.
- The loop is synchronous, uses fresh in-memory history, executes tools serially,
  and trusts the host to enforce tool availability and authorization. It lacks
  cancellation, asynchronous streaming, persistence, and other advanced Core
  features. Multiple tool calls are validated and executed sequentially, rather
  than all being prepared before invocation as in Go. Events contain only their
  type. `praxo_core` provides memory, event sinks, checkpoints, lexical path
  policy, context compaction, PII/structured-output helpers, call limits, and
  tool selection; the agent loop does not automatically apply every opt-in helper.
- SDK-local exceptions are not new shared wire error codes. Passing the eleven
  vector groups does not imply full Go feature parity or production readiness.

The source is MIT; see [LICENSE](LICENSE). Free Pascal, its RTL, `fpjson`, and
`RegExpr` are separate toolchain components, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/delphi.md), and
[implementation support](../../docs/languages/support.md).
