# Haskell Setup And Tests

Install GHC 9.0 or newer and Python 3.10 or newer. The SDK uses the GHC boot
packages `base` and `containers`; Cabal is optional. The reported Windows run
used GHC 9.12.2. From the repository root, adjust the compiler path for the
local installation:

```powershell
$env:GHC = 'D:\dev\ghc-9.12.2-x86_64-unknown-mingw32\bin\ghc.exe'
& $env:GHC --version
python language/haskell/run-tests.py
python language/haskell/api-snapshot.py --check
```

The test driver builds and runs the native regression tests and all declared
conformance vector groups, and checks the API snapshot and existing parity
inventory. The reported Windows run passed 28 vectors and the negative usage
tests; the driver's successful run includes the snapshot check. Alternatively
pass `--compiler` to select GHC. Build products go to `language/haskell/build/`.

To exercise the conformance executable's argument validation after the driver
builds it, run from the repository root. Both invocations should print usage
and exit nonzero:

```powershell
& language/haskell/build/conformance/run.exe
$LASTEXITCODE
& language/haskell/build/conformance/run.exe spec extra
$LASTEXITCODE
```

Broader repository metadata and parity checks can be run separately:

```powershell
python scripts/test_layout.py
$env:GOWORK = 'off'
go test ./internal/spec/...
```

On Windows, the standalone snapshot check passed, the layout check passed all
8 tests, and the Go specification tests passed. The broader checks are not
part of the Haskell test driver.

With Cabal and boot packages available, from `language/haskell/`:

```text
cabal build --offline all
cabal test --offline
cabal run --offline praxo-haskell-conformance -- ../../spec
```

The Cabal commands were not verified in the reported Windows run. Offline
execution requires Cabal and the necessary dependencies to be available locally.

Regenerate the source API inventory after reviewing intentional API changes with
`python language/haskell/api-snapshot.py`. The shared parity inventory currently
does not describe the new agent loop.
