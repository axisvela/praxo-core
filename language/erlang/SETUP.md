# Erlang Environment Setup

The verified toolchain is Erlang/OTP 29 with its `json` module and Python 3.10
or newer. On the development machine Erlang is installed under
`D:\dev\Erlang OTP`; use your own installation path and make `erlc` and `erl`
available on `PATH`, or set `ERLC` and `ERL`.

From the repository root in PowerShell:

```powershell
$env:Path = "D:\dev\Erlang OTP\bin;$env:Path"
python language/erlang/run-tests.py
python language/erlang/api-snapshot.py --check
$env:GOWORK = "off"
go test ./internal/spec
```

The runner checks the API snapshot and parity inventory, compiles the sources,
conformance runner, and tests with `erlc`, then runs both suites with `erl`
against the repository `spec/` directory. Compilation output goes to
`language/erlang/build/ebin/`.

Manual commands from `language/erlang/`:

```powershell
erlc -I src -o build/ebin src/*.erl conformance/*.erl tests/*.erl
erl -noshell -pa build/ebin -eval "praxo_conformance:main()." -s init stop
erl -noshell -pa build/ebin -eval "praxo_tests:run()." -s init stop
```

The vector suite covers all eleven declared groups. The native tests cover JSON,
tool-call parsing, JSON Schema, plugin manifests, memory, checkpoints, context
compaction, policy paths, event sinks, middleware, tool selection, fallback
models, custom models, and call limits.

These checks do not establish production readiness, provider integration,
streaming, or plugin-host behavior. Path checks are lexical, not OS
containment. Core-local errors are not new wire error codes.
