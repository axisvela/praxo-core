# Fortran Environment Setup

Run commands from the repository root unless otherwise stated. The Fortran SDK
is a native Core implementation; Python is needed for its build and test
tooling, not by a compiled SDK consumer.

## Prerequisites

- Python 3.10 or later, available as `python`.
- GNU Fortran (`gfortran`), installed and managed by the developer. The
  compiler and its runtime are separate toolchain dependencies, not vendored by
  this repository.

On Windows, the observed developer-managed compiler directory was
`D:\dev\winlibs\mingw64\bin`. This is a local example, not a required path.
Configure the directory for your own installation in PowerShell:

```powershell
$env:GFORTRAN_BIN = "C:\path\to\mingw64\bin"
$env:Path = "$env:GFORTRAN_BIN;$env:Path"
python --version
gfortran --version
```

For the observed layout, set `$env:GFORTRAN_BIN` to
`D:\dev\winlibs\mingw64\bin` instead. Ensure the compiler and its runtime
dependencies are available; the driver prepends the selected compiler's
directory to `PATH` when compiling and running tests.

## Driver

```powershell
python language/fortran/run-tests.py
```

The driver defaults to `gfortran` on `PATH`. Alternatively, set `FC` to the
compiler executable or pass `--compiler`; the command-line option takes
precedence over `FC`:

```powershell
$env:FC = "C:\path\to\mingw64\bin\gfortran.exe"
python language/fortran/run-tests.py
python language/fortran/run-tests.py --compiler "C:\path\to\mingw64\bin\gfortran.exe"
```

The driver checks the API snapshot and Python tooling, generates Fortran fixture
tests from `spec/vectors/`, and compiles and runs the core, JSON, contract, and
fixture suites. It uses Fortran 2008 mode, warnings as errors, and runtime
checks. Generated fixtures, modules, and executables are placed in
`language/fortran/build/`. The fixture generator checks the vector group
inventory and rejects unknown operations; behavior is tested in compiled Fortran.

## Ancillary Checks

Run the snapshot and tooling checks independently when working on those areas:

```powershell
python language/fortran/api-snapshot.py --check
python language/fortran/tests/tooling.py
```

For an intentional API change, review the declarations and regenerate the
snapshot with `python language/fortran/api-snapshot.py --update`,
then rerun the checks. The snapshot is a source declaration inventory, not a
binary ABI guarantee. The full driver remains the native test and conformance
command.

Repository-wide layout and specification checks can also be run separately:

```powershell
python scripts/test_layout.py
$env:GOWORK = "off"
go test ./internal/spec/...
```

## Reported Results

An earlier `python language/fortran/run-tests.py` run passed the API snapshot,
5 tooling tests, 69 native assertions, 59 JSON assertions, 62 contract
assertions, and 62 conformance vectors across 11 groups. These results are
historical evidence, not a claim that the checks were rerun for this document.
The source release tag is `fortran/v0.2.0`. This does not establish a
package-registry release or remove the documented partial surfaces. See
`language/fortran/README.md` and
`spec/parity/fortran.md` for scope and remaining gates.
