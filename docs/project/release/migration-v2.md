# PRAXO-CORE v2 Migration

**Status:** v2 branch, 2026-10-18.

v2 changes the Go module path for semantic import versioning. The exported API,
capability packages, JSON tags, and wire contracts are unchanged from 1.7.0.

## Module Path

```go
require github.com/axisvela/praxo-core/v2 v2.0.0
```

All imports change from:

```go
"github.com/axisvela/praxo-core/pkg/agent"
```

to:

```go
"github.com/axisvela/praxo-core/v2/pkg/agent"
```

## Consumer Steps

1. Update `go.mod`:

   ```sh
   go get github.com/axisvela/praxo-core/v2@v2.0.0
   ```

2. Rewrite imports in source files:

   ```sh
   rg -l '"github.com/axisvela/praxo-core/' | xargs sed -i \
     's#"github.com/axisvela/praxo-core/#"github.com/axisvela/praxo-core/v2/#g'
   ```

   On PowerShell:

   ```powershell
   Get-ChildItem -Recurse -Filter *.go | ForEach-Object {
     $c = [System.IO.File]::ReadAllText($_.FullName)
     $n = $c.Replace('"github.com/axisvela/praxo-core/', '"github.com/axisvela/praxo-core/v2/')
     if ($n -ne $c) {
       [System.IO.File]::WriteAllText($_.FullName, $n, (New-Object System.Text.UTF8Encoding($false)))
     }
   }
   ```

3. Remove any v1 `replace` directive or point it at the v2 checkout.
4. Run `go mod tidy`, `go test ./...`, and `go build ./...`.

## Compatibility

- Root `agent.*` aliases remain, so capability types do not need to be imported
  from subpackages unless desired.
- v1 tags remain available for consumers that have not migrated.
- v2 does not remove `toolcall.ToolCall` governance metadata; that remains a
  product contract used by PRAXOVELA.

## Language Directory

Independent language implementations have moved from `sdk/` to `language/`.
Update checkout paths, scripts, and links accordingly; package names and Core
release tags such as `python/v0.2.0` are unchanged. Historical tags retain the
repository layout they had when published, including `sdk/` where applicable;
use `language/` when referring to the current checkout.

## Release Gate

Do not publish `v2.0.0` until PRAXOVELA/open and EE have a v2 branch that
passes their full test suites.
