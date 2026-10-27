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

For Linux x86-64, CI uses the official `0.5.2` release archive rather than
building from source:

```bash
gh release download 0.5.2 --repo vlang/v --pattern v_linux.zip
echo '86caf9e70c3342d48ef19eb4f6c47b709f18c90ae86255520d5c29df6b482e23  v_linux.zip' | sha256sum --check
unzip -q v_linux.zip
export PATH="$PWD/v:$PATH"
v version
```

The checksum matches the GitHub release asset digest. CI uses the runner's
compiler environment and adds the extracted `v` directory to `PATH`.
Other platforms need their corresponding release archive.

Job [122092667286](https://github.com/axisvela/praxo-core/actions/runs/40475516685/job/122092667286)
for commit `e7fd5a7` failed during installation, before SDK checks. Its `make`
cloned the moving `vlang/vc` default branch and ran `v1` against the 0.5.2
source; `vlib/math/bits/bits.v:621` then failed on a parenthesized `if`
expression. The release archive avoids that unpinned bootstrap. The downloaded
archive's SHA-256 was checked locally against the release API digest; the new
Linux CI installation and SDK checks have not yet been verified remotely.

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
steps, errors, and fallback. Opt-in tool selection is exercised in agent runs.
PII, structured output, and call limit remain standalone helpers.
Built-in provider integrations, streaming wire encodings, and plugin hosts are
not provided; see the README for the callback contract and other limits.

## Results

For this turn, local Windows testing with V 0.5.2, bundled tcc, and `-gc none`
passed the tests and conformance vectors. The API snapshot and repository-wide
checks are listed above but are not claimed as part of these reported results.
Remote CI results are pending.

With V 0.5.2 and `-cc tcc -gc none`, the tests, conformance runner, and API
snapshot check passed again after the tool-selection integration. Remote CI for
these changes is pending.
