# Elixir And Erlang Environment Setup

This page records the manual toolchain procedure used to verify the Elixir
SDK. Commands run from the repository root unless noted.

## Verified Local Layout

The verified Windows environment used:

- Erlang/OTP `29.1.2`
- Elixir `1.20.4`, built for OTP 29
- Compiled BEAM files in `language\elixir\build\ebin`

The repository does not require these directories. CI and other developers may
use any location; only `erl` and `elixir` need to be on `PATH`.

## Manual Install Of Erlang/OTP

1. Download the 64-bit Windows installer from the official Erlang/OTP releases
   page: `https://github.com/erlang/otp/releases`.
2. Run the installer and choose the desired directory, for example
   a directory of your choice.
3. Add its `bin` directory to `PATH`:

   ```powershell
   $env:ERLANG_HOME = "$env:USERPROFILE\tools\erl"
   $env:Path = "$env:ERLANG_HOME\bin;$env:Path"
   ```

4. Verify the runtime:

   ```powershell
   erl -version
   ```

The Elixir SDK requires OTP 27 or newer because it uses the standard `:json`
module. The verified release is OTP 29.1.2.

## Manual Install Of Elixir

1. Download the precompiled archive that matches the installed OTP release from
   `https://github.com/elixir-lang/elixir/releases`. For OTP 29 use
   `elixir-otp-29.zip`.
2. Extract it into a developer-controlled directory, for example
   a directory of your choice.
3. Add its `bin` directory to `PATH` after Erlang:

   ```powershell
   $env:ELIXIR_HOME = "$env:USERPROFILE\tools\elixir"
   $env:Path = "$env:ELIXIR_HOME\bin;$env:Path"
   ```

4. Verify both components:

   ```powershell
   elixir --version
   ```

The output should show Elixir 1.20.4 and Erlang/OTP 29. Set the example
variables to the actual installation directories before updating `PATH`.

## Encoding Requirement

The Elixir parser rejects a UTF-8 byte-order mark. Keep `.ex` and `.exs` files
UTF-8 without BOM. `elixirc` and the scripts in this repository are stored
without BOM.

## Build

From the repository root in PowerShell, pass the files explicitly:

```powershell
New-Item -ItemType Directory -Force -Path language/elixir/build/ebin | Out-Null
elixirc -o language/elixir/build/ebin (Get-ChildItem language/elixir/lib/praxo/*.ex).FullName
```

## Environment Variables

No repository-specific environment variable is required. `PATH` must contain
the Erlang and Elixir `bin` directories. `ERL_LIBS` and `MIX_ENV` are not used
by the documented commands.

## Test Scripts

Run the SDK checks from the repository root in PowerShell after building:

```powershell
elixir -pa language/elixir/build/ebin language/elixir/tests/run_tests.exs
python language/elixir/api-snapshot.py --check
elixir -pa language/elixir/build/ebin language/elixir/conformance/run.exs
```

The local tests exercise consumer model callbacks across tool steps, errors,
fallback, opt-in tool selection, PII redaction, structured validation and
repair, repairer exceptions and failure lifecycle, and per-run model and tool limits. See the README for the contracts and
limitations.

For repository-wide metadata and parity checks, run `python scripts/test_layout.py`
and `$env:GOWORK = "off"; go test ./internal/spec/...` separately.

## Results

On Windows with Elixir 1.20.4 and Erlang/OTP 29, the build, tests, eleven
conformance vector groups, and API snapshot check passed after the opt-in
agent-loop integrations. The configured `elixir-conformance` job uses
`erlef/setup-beam@v1`; remote CI for these changes is pending.
