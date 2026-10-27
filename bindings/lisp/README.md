# Lisp Bridge (SBCL)

A Common Lisp bridge with source tag `lisp/v0.1.0` over the maintained
`praxo-bridge` runtime. It does not implement another agent loop or duplicate
model, tool, policy, or plugin behavior. Local validation uses SBCL 2.6.9 on
Windows, and the Linux CI job covers the bridge.

## Run

Set `PRAXO_BRIDGE_BIN` to a built bridge executable, then invoke the script:

```bash
echo '{}' | sbcl --script bindings/lisp/praxo-bridge.lisp version
echo '{"content":"{\"name\":\"echo\",\"input\":{}}"}' \
  | sbcl --script bindings/lisp/praxo-bridge.lisp toolcall parse
```

Without `PRAXO_BRIDGE_BIN`, the wrapper runs `go run ./cmd/praxo-bridge` from
the current directory. Build the bridge first with:

```bash
go build -o build/praxo-bridge ./cmd/praxo-bridge
```

From the repository root, run the bridge tests with:

```bash
python bindings/lisp/test_bridge.py
```

Set `SBCL` to select a compiler. The test builds the bridge, sends raw UTF-8
JSON over stdin, checks JSON output, and verifies exit-code propagation.

## Contract and Limits

- Input is one JSON object on stdin; output is one JSON object on stdout;
  diagnostics stay on stderr; exit code `0`, `1`, or `2` is preserved.
- The wrapper does not parse or rewrite tool-call markup or policy decisions.
- Credentials must come from environment variables or a config file, never
  argv. The wrapper does not expose a credential option.
- SBCL standard streams are UTF-8 in the verified environment. Callers should
  pass raw UTF-8 bytes (for example through Python or a UTF-8 file), not a
  PowerShell string pipe that may transcode non-ASCII text.
- The bridge uses the Go runtime's supported command set and limits; see
  [`spec/bridge.md`](../../spec/bridge.md). No separate Lisp wire codec is
  claimed.
- A consumer was reported by the maintainer, but the consumer identity and
  production evidence are not yet recorded. The source tag does not establish
  package-registry publication or production readiness.

The source is MIT; see [LICENSE](../../LICENSE). SBCL is a separate runtime,
not vendored code.
