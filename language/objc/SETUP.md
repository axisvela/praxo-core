# Objective-C Environment Setup

This page records the manual toolchain procedure used to verify the
Objective-C SDK. Commands run from the repository root unless noted.

## Verified Local Layout

The verified Windows environment used:

- clang `21.1.8` and lld from MSYS2
- GNUstep Base `1.31.1` and the GNUstep Objective-C runtime
- Windows x86_64, with GNUstep runtime DLLs on `PATH`

The repository does not require these directories. The reported Windows
`python language/objc/run-tests.py` run passed 113 checks, including lexical
traversal checks. This also includes the driver's API snapshot and parity
check. macOS verification is pending; CI configuration using Apple clang and
Foundation is not evidence of a verified macOS run.

## Manual Install On Windows

1. Install MSYS2 and the clang/lld packages, or use another clang 21 build.
2. Install GNUstep Base and libobjc2 into the MSYS2 environment or a separate
   developer-controlled directory.
3. Add clang and the GNUstep runtime DLL directory to `PATH`:

   ```powershell
   $env:Path = "C:\tools\msys64\mingw64\bin;C:\tools\GNUstep\bin;$env:Path"
   ```

4. Verify the compiler and runtime:

   ```powershell
   clang --version
   ```

5. For a manual build, first change to `language/objc` and create `build` if
   needed. Build with the GNUstep ABI and lld. The `-lstdc++` link is required
   by the verified clang/Blocks combination:

   ```powershell
   Set-Location language/objc
   New-Item -ItemType Directory -Force build
   clang -fobjc-arc -fblocks -I. -o build\praxo_tests.exe `
     PraxoJSON.m PraxoJsonSchema.m PraxoPlugin.m PraxoWire.m `
     PraxoCore.m PraxoAgent.m tests\main.m tests\correlation.m `
     -fobjc-runtime=gnustep-2.0 -fuse-ld=lld `
     -lgnustep-base -lobjc -lstdc++
   build\praxo_tests.exe ..\..\spec
   ```

## Manual Install On macOS

Verification on macOS is pending. Use the Xcode command-line tools or a clang
toolchain with Foundation. From `language/objc`, create `build` first. Blocks
are native and no `-lstdc++` link is needed:

```bash
mkdir -p build
clang -fobjc-arc -fblocks -I. -o build/praxo_tests \
  PraxoJSON.m PraxoJsonSchema.m PraxoPlugin.m PraxoWire.m \
  PraxoCore.m PraxoAgent.m tests/main.m tests/correlation.m \
  -framework Foundation
build/praxo_tests ../../spec
```

## Environment Variables

No repository-specific environment variable is required. `PATH` must contain
`clang` and, on Windows, the GNUstep runtime directory. Set `CLANG` to select a
specific compiler for `run-tests.py`.

## Test Scripts

Run the Objective-C checks from the repository root:

```bash
python language/objc/api-snapshot.py --check
python language/objc/run-tests.py
```

Run broader repository metadata and parity checks separately (PowerShell):

```powershell
python scripts/test_layout.py
$env:GOWORK = 'off'
go test ./internal/spec/...
```

`run-tests.py` compiles the native SDK, runs all eleven vector groups and the
native regression checks, and verifies the API snapshot/parity. The broader
commands cover repository-wide metadata and parity and are not part of the
test driver. On Windows, the standalone snapshot check passed, the layout check
passed all 8 tests, and the Go specification tests passed. GNUstep headers,
libraries, lld, and runtime DLLs must be discoverable by the selected compiler
and Windows loader; the example paths may need adjustment for the installation.
