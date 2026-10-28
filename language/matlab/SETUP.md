# MATLAB/Octave Setup

The reported local environment used GNU Octave 11.3.0 on Windows and Python
3.10 or later. MATLAB compatibility is a target and has not been independently tested.
Octave is a separate GPL-licensed interpreter; the Core is MIT-licensed.

On the Windows development environment, the Octave CLI is at
`D:\dev\octave-11.3.0-w64\mingw64\bin\octave-cli.exe`. From the repository
root, run:

```powershell
python language/matlab/run-tests.py --octave "D:\dev\octave-11.3.0-w64\mingw64\bin\octave-cli.exe"
python language/matlab/api-snapshot.py --check
```

Alternatively put `octave-cli` on `PATH` or set `$env:OCTAVE` to its executable path.
`run-tests.py` checks the API snapshot and parity inventory, then launches
`run_tests.m` with startup files and history disabled. `run_tests.m` checks the
spec version and vector group headers, then runs `tests/test_json.m`,
`tests/test_toolcall.m`, `tests/test_schema.m`, `tests/test_manifest.m`, and
`tests/test_agent.m` and the additional group tests. All eleven vector groups
and the native regression scripts run under Octave.

The reported Windows run of `run-tests.py` with the executable above passed all
eleven vector groups and the native tests. Actual MATLAB and remote CI remain
unverified.

`api-snapshot.py --check` verifies `api/0.2.0.txt`, the contract version,
and symbols in `spec/parity/matlab.md`. Without `--check` it regenerates the
local snapshot. The shared Go spec checks can also be run from the repository
root:

```powershell
$env:GOWORK = 'off'
go test ./internal/spec
```

No result for that shared Go check is claimed here. These checks cover the
declared Core gate under Octave; MATLAB itself is not independently verified.
