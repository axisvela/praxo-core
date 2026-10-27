# Nim Environment Setup

This page records the manual toolchain procedure used to verify the Nim SDK.
Commands run from the repository root unless noted.

## Verified Local Layout

The verified Windows environment used:

- Nim `2.2.12`
- MinGW `gcc 15.2.0` from MSYS2
- Executables written to `build\` in the repository

The repository does not require these directories. CI and other developers may
use any location; only `nim` and a C compiler need to be on `PATH`.

## Manual Install On Windows

1. Download the x86_64 Windows archive from the official Nim download page:
   `https://nim-lang.org/install_windows.html`.
2. Extract the archive into a developer-controlled tools directory. The
   archive contains `bin\nim.exe`, `lib`, and `finish.exe`.
3. Add the `bin` directory and the Nimble binary directory to `PATH`:

   ```powershell
   $env:NIM_HOME = "$env:USERPROFILE\tools\nim"
   $env:Path = "$env:NIM_HOME\bin;$env:USERPROFILE\.nimble\bin;$env:Path"
   ```

   `finish.exe` can add these entries permanently and can install MinGW.
4. Install or locate a C compiler. The verified setup used MSYS2 MinGW:

   ```powershell
   $env:MSYS2_HOME = "$env:USERPROFILE\tools\msys64"
   $env:Path = "$env:MSYS2_HOME\mingw64\bin;$env:Path"
   gcc --version
   ```

5. Verify the compiler:

   ```powershell
   nim --version
   ```

Set the example variables to the actual installation directories. The SDK
commands below provide the compilation check without creating a smoke-test file.

## Manual Install On Linux And CI

Install Nim from the official archive or a distribution package, then ensure
`gcc` is present:

```bash
sudo apt-get update
sudo apt-get install -y gcc
# install Nim 2.2.12 from the official archive or a setup action
nim --version
```

The configured `nim-conformance` CI job installs Nim `2.2.12` with
`jiro4989/setup-nim-action@v2`.

## Environment Variables

No repository-specific environment variable is required. `PATH` must contain
`nim` and the selected C compiler. Nim's cache may be redirected with
`NIMCACHE` if the default user cache is not writable.

## Test Scripts

Run the SDK checks from the repository root in PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path build | Out-Null
python language/nim/api-snapshot.py --check
nim c --path:language/nim/src --hints:off --out:build/praxo-nim-conformance.exe language/nim/conformance/run.nim
.\build\praxo-nim-conformance.exe
nim c --path:language/nim/src --hints:off --out:build/praxo-nim-tests.exe language/nim/tests/run_tests.nim
.\build\praxo-nim-tests.exe
```

On Linux omit the `.exe` suffix and use `./build/...`. For repository-wide
metadata and parity checks, run `python scripts/test_layout.py` and
`$env:GOWORK = "off"; go test ./internal/spec/...` separately in PowerShell.

The tests cover the synchronous `callbackModel` adapter across agent steps,
errors, and fallback. PII, structured output, call limit, and tool selection
remain standalone helpers rather than integrated agent middleware. Built-in
provider integrations, streaming wire encodings, and plugin hosts are not
provided; see the README for the callback contract and other limits.

## Results

For this turn, local Windows testing with Nim 2.2.12 and MinGW GCC 15.2.0
passed the tests and conformance vectors, with unused import warnings. The API
snapshot and repository-wide checks are listed above but are not claimed as
part of these reported results. Remote CI results are pending.

In a subsequent local Windows session, `python language/nim/api-snapshot.py
--check` passed with Python 3.14.6. Nim was not on `PATH`, so tests and
conformance were not rerun in that session; the earlier results above are not
evidence of a fresh run against the callback changes.
