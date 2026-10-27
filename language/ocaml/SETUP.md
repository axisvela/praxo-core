# OCaml Environment Setup

The local Windows checks used OCaml 4.14.2 bytecode from a developer-managed
DkML installation and Python 3. Set the compiler path and standard-library
path to match your own installation; the repository does not require a
particular drive or user directory.

For example, the following PowerShell commands reproduce the local setup from
the repository root. `D:\dev\dkml` is the installation used on that machine;
replace it with your own DkML installation path:

```powershell
$dkml = "D:\dev\dkml"
$env:Path = "$dkml\desktop\bc\bin;$dkml\usr\bin;$env:Path"
$env:OCAMLLIB = "$dkml\desktop\bc\lib\ocaml"
& "$dkml\desktop\bc\bin\ocamlc.exe" -version
python language/ocaml/run-tests.py --compiler "$dkml\desktop\bc\bin\ocamlc.exe"
python language/ocaml/api-snapshot.py --check
python scripts/test_layout.py
$env:GOWORK = "off"
go test ./internal/spec/...
```

The runner locates `ocamlrun` on `PATH` or next to the compiler. It checks the
API snapshot and parity, compiles the interface, implementation and tests, and
runs the bytecode test executable against `spec/`. On the stated Windows setup,
the 11 vector test groups, middleware integration tests, and agent failure tests
passed, as did the API parity snapshot check. Compilation emitted existing
pattern match warnings.

These checks cover the declared Core gate on bytecode OCaml. Native `ocamlopt`
is not exercised. Path checks are lexical, not OS containment.
