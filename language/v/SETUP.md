# V Environment Setup

This page records the manual toolchain procedure used to verify the V SDK.
Commands run from the repository root unless noted.

## Verified Local Layout

The verified Windows environment used:

- V `0.5.2` (`7647ce1`)
- Bundled C compiler: `thirdparty\tcc\tcc.exe`
- Optional fallback compiler: MinGW `gcc` on `PATH`

The repository does not require a particular installation directory. The
commands below use V's bundled tcc; other compiler configurations may differ.

## Manual Install On Windows

1. Download `v_windows.zip` from the official V releases page:
   `https://github.com/vlang/v/releases`.
2. Extract the archive into a developer-controlled tools directory. The archive
   contains a top-level `v` directory with `v.exe` and `thirdparty\tcc`.
3. Add the directory containing `v.exe` to `PATH`, for example:

   ```powershell
   $env:V_HOME = "$env:USERPROFILE\tools\v"
   $env:Path = "$env:V_HOME;$env:Path"
   ```

4. Verify the compiler:

   ```powershell
   v version
   ```

Set `V_HOME` to the actual directory containing `v.exe`. The SDK commands
below verify compilation with the bundled compiler.

If `gcc` is used instead of `tcc`, pass `-cc gcc`. The verified Windows setup
used `-cc tcc -gc none` because the MinGW build required a different libgc
configuration.

## Manual Install On Linux And CI

Use the official source build or a release archive. A minimal source build is:

```bash
git clone --depth 1 https://github.com/vlang/v
cd v
make
sudo ./v symlink
```

Install a C compiler (`build-essential` or `gcc`) before building. The
configured `v-conformance` CI job clones the pinned `0.5.2` tag, builds V from
source with `make`.

## Environment Variables

No repository-specific environment variable is required. `PATH` must contain
`v`; an external C compiler must also be available when not using bundled tcc.
`VFLAGS` is optional and should not be required for the documented commands.

## Test Scripts

Run the SDK checks from the repository root in PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path build | Out-Null
python language/v/api-snapshot.py --check
v -cc tcc -gc none -o build/praxo-v-conformance.exe language/v/conformance/run.v
.\build\praxo-v-conformance.exe
v -cc tcc -gc none -o build/praxo-v-tests.exe language/v/tests/run.v
.\build\praxo-v-tests.exe
```

For repository-wide metadata and parity checks, run `python scripts/test_layout.py`
and `$env:GOWORK = "off"; go test ./internal/spec/...` separately in PowerShell.

The tests cover the synchronous `praxo.callback_model` adapter across agent
steps, errors, and fallback. PII, structured output, call limit, and tool
selection remain standalone helpers rather than integrated agent middleware.
Built-in provider integrations, streaming wire encodings, and plugin hosts are
not provided; see the README for the callback contract and other limits.

## Results

For this turn, local Windows testing with V 0.5.2, bundled tcc, and `-gc none`
passed the tests and conformance vectors. The API snapshot and repository-wide
checks are listed above but are not claimed as part of these reported results.
Remote CI results are pending.

In a subsequent local Windows session, `python language/v/api-snapshot.py
--check` passed with Python 3.14.6. V was not on `PATH`, so tests and
conformance were not rerun in that session; the earlier results above are not
evidence of a fresh run against the callback changes.
