# Objective-C Representative Chain

Deterministic representative chain covering MCP record, final-argument
authorization, governed child delegation, OTel/Harmovela events, and an edited
denial with zero effects.

From `language/objc/`, compile all `src/Praxo*.m` files plus this example with
the GNUstep flags from `run-tests.py`, then run the binary with the GNUstep
runtime directory on `PATH`. Expected output:

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 7
harmovela events: 7
denied effects: 0
```

Validated with clang 21 / GNUstep Base on Windows. macOS Apple Foundation and
package-registry publication remain unverified.
