# PRAXO-CORE Erlang Core

Erlang is a native Core implementation with source tag `erlang/v0.1.0`. It
passes all eleven shared vector groups on Erlang/OTP 29 and includes the native
agent loop, memory store, checkpoint allowlist, lexical path policy, context
compaction, event sinks, middleware helpers, and tool selection. It does not
call Go or another Core.

- Implementation type: Core.
- Package version: `0.1.0`; supported `SPEC_VERSION`: `0.2.0`.
- Toolchain: Erlang/OTP 29 or newer. JSON uses the OTP `json` module.
- Local gate: eleven vector groups, native regression tests, API snapshot, and
  parity inventory.

## Build and Test

From the repository root:

```bash
python language/erlang/run-tests.py
python language/erlang/api-snapshot.py --check
```

Set `ERLC` and `ERL` to select the compiler and runtime. The Python runner only
launches `erlc`, `erl`, and the API checks; the implementation and tests are
Erlang. Build output stays under `language/erlang/build/ebin/`.

To build manually from `language/erlang/`:

```bash
erlc -I src -o build/ebin src/*.erl conformance/*.erl tests/*.erl
erl -noshell -pa build/ebin -eval "praxo_conformance:main()." -s init stop
erl -noshell -pa build/ebin -eval "praxo_tests:run()." -s init stop
```

## Usage

```erlang
Model = praxo_agent:static_model(<<"hello">>),
Options = praxo_agent:new_agent_options(Model),
{ok, Result, _Options} =
    praxo_agent:run_agent(Options, praxo_models:session(<<"demo">>), <<"hello">>),
io:format("~s~n", [maps:get(output, Result)]).
```

Public declarations are inventoried in [`api/0.1.0.txt`](api/0.1.0.txt).
This is a source declaration check, not a binary ABI promise. Regenerate it with
`python api-snapshot.py`.

## Current Limits

- The verified target is Erlang/OTP 29. Older releases without the `json`
  module are not supported.
- No provider adapter, streaming runtime, plugin host, or persistent session
  store is provided. The loop is synchronous and executes tools serially.
- PII redaction, structured output, per-run call limits, and tool selection are
  opt-in and integrated into the agent loop.
- Path checks are lexical and do not resolve symlinks or reparse points; they
  are not an OS containment boundary.
- Model and tool callbacks are caller-supplied functions. Callback exceptions
  are not converted to contract errors.
- Core-local errors and exception terms are not new shared wire error codes.
  Passing the vectors does not establish full Core parity or production
  readiness.

The source is MIT; see [LICENSE](LICENSE). Erlang/OTP is a separate toolchain,
not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/erlang.md),
[SETUP.md](SETUP.md), and
[implementation support](../../docs/languages/support.md).
