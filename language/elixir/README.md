# PRAXO-CORE for Elixir

Elixir is a native Core implementation targeting the PRAXO-CORE contract. It
passes all eleven shared vector groups with `Elixir 1.20.4` on `Erlang/OTP 29`
and includes the native agent loop, context compaction, memory store, path
policy, checkpoint allowlist, tool-call parsing, and opt-in tool selection. PII,
structured output, and call limit are standalone helpers, not integrated agent
middleware. Vector coverage does not establish full Core parity or production
readiness.

The SDK uses the OTP 27+ `:json` module and does not call Go or another
language runtime. Erlang shares the BEAM runtime and does not add a second
agent loop. Provider adapters and plugin hosts remain outside the declared Core
scope.

## Build And Test

From `language/elixir`:

```bash
elixirc -o build/ebin lib/praxo/*.ex
elixir -pa build/ebin tests/run_tests.exs
cd ../..
python language/elixir/api-snapshot.py --check
elixir -pa language/elixir/build/ebin language/elixir/conformance/run.exs
```

The conformance runner reads `spec/` from the repository root. On PowerShell,
expand the source files explicitly:

```powershell
elixirc -o build/ebin (Get-ChildItem lib/praxo/*.ex).FullName
```

The complete local environment procedure, including manual Erlang and Elixir
installation, is in [SETUP.md](SETUP.md).

## API

```elixir
{:ok, call} = Praxo.ToolCallParser.parse_tool_call(
  ~s(<tool_call name="echo">{"text":"hi"}</tool_call>)
)

assert call.name == "echo"

schema = Praxo.Json.parse!(~s({"type":"string","pattern":"^a+$"}))
assert Praxo.JsonSchema.validate(schema, "aaa") == []
```

Public declarations are inventoried in [`api/0.1.0.txt`](api/0.1.0.txt).

An agent model can be a function accepting a `Praxo.Request` and returning
`{:ok, %Praxo.Response{}}` or `{:error, code}`, where `code` is a string:

```elixir
model = fn request ->
  {:ok, Praxo.Models.response(Praxo.Models.message_assistant("received #{length(request.messages)} messages"))}
end

options = Praxo.Agent.new_agent_options(model)
{:ok, result, options} = Praxo.Agent.run_agent(options, Praxo.Models.session("s1"), "hello")
```

The callback receives the current messages and tool specifications on each
step. It can also be either child of `Praxo.Agent.fallback_model/2`.
Manage any provider state externally; the callback itself is retained unchanged
in returned options. Return errors explicitly to trigger failure or fallback;
exceptions and malformed returns are not converted into model errors.

Set `tool_selection` to opt into filtering advertised tools and rejecting calls
to unselected names before invocation:

```elixir
options = %{options | tool_selection: Praxo.Middleware.tool_selection(["echo"])}
```

The default `nil` advertises and permits all registered tools as before. An
empty selection advertises none and rejects every tool call with
`AGENT_TOOL_NOT_SELECTED`. A selected but unregistered name still fails with
`TOOL_NOT_FOUND`. This is an agent-loop restriction, not a sandbox for direct
calls to `Praxo.Agent.call/2`.

## Current Limits

- Verified with `Elixir 1.20.4` and `Erlang/OTP 29` on Windows. Other OTP
  releases, other Elixir releases, and remote CI are not yet verified.
- JSON requires OTP 27 or newer and uses the `:json` module. Invalid JSON and
  trailing data are rejected; JSON `null` is represented by the `:null` atom.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. Generated call IDs are not provided. Markup stripping is not an
  authorization control or sanitizer.
- Schema patterns use Elixir `Regex`. Invalid patterns produce a validation
  error rather than being silently accepted.
- Path checks are lexical and confined by separator boundaries. They do not
  resolve symlinks or replace operating-system sandboxing.
- Provider adapters, streaming wire encodings, and plugin hosts are not part of
  this SDK.
- Provider callbacks are synchronous; streaming and built-in provider
  configuration are not provided.

The source is MIT; see [LICENSE](LICENSE). Erlang, Elixir, and other toolchain
components are separate projects, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/elixir.md), and
[implementation support](../../docs/languages/support.md).
