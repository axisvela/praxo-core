# Octave Environment Setup

The reported local environment used GNU Octave 11.3.0 on Windows and Python
3.10 or later. Octave is a separate GPL-licensed interpreter; the Core is
MIT-licensed.

From the repository root:

```powershell
python language/octave/run-tests.py --octave "D:\dev\octave-11.3.0-w64\mingw64\bin\octave-cli.exe"
python language/octave/api-snapshot.py --check
```

Alternatively put `octave-cli` on `PATH` or set `$env:OCTAVE` to its executable
path. `run-tests.py` checks the API snapshot and parity inventory, then launches
`run_tests.m`. The tests cover all eleven vector groups and the native
regression scripts. Linux CI runs the same suite with the distribution Octave.

`api-snapshot.py --check` verifies `api/0.5.0.txt`, the contract version, and
symbols in `spec/parity/octave.md`. Without `--check` it regenerates the local
snapshot.

The shared Go spec checks can also be run from the repository root:

```powershell
$env:GOWORK = 'off'
go test ./internal/spec
```

These checks cover the declared Core gate under Octave. MATLAB runtime
verification is separate.
