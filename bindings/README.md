# Runtime Bindings

Shell and PowerShell wrappers delegate to `cmd/praxo-bridge`; they do not
implement another agent loop. Use a prebuilt executable through
`PRAXO_BRIDGE_BIN`, or use the source fallback with Go installed.

- [Shell wrapper](shell/README.md)
- [PowerShell module](powershell/README.md)
- [Lisp bridge](lisp/README.md)
- [Tcl bridge](tcl/README.md)
- [Bridge contract](../spec/bridge.md)
- [Source path migration](../docs/project/repository-layout.md)
