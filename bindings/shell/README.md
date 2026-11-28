# Shell Bridge

Thin wrapper over `praxo-bridge` following `spec/bridge.md`.

```bash
echo '{"content":"echo.run {\"text\":\"hi\"}"}' | ./bindings/shell/praxo-bridge.sh toolcall parse
echo '{"prompt":"hello"}' | PRAXO_BASE_URL=http://localhost:11434/v1 ./bindings/shell/praxo-bridge.sh run
```

Set `PRAXO_BRIDGE_BIN` to use a prebuilt binary. Otherwise the wrapper runs
`go run ./cmd/praxo-bridge`.

The wrapper preserves stdout JSON, stderr diagnostics, and the bridge exit
codes. Do not interpolate untrusted JSON into shell commands.

## Representative Chain and Governance

The bridge exposes one-shot `run`, `toolcall`, `jsonschema`, `tool`, `event`, and
`plugin` commands. It has no local agent loop, subagent manager, or child-policy
surface, so a bridge-local chain/delegation example is not applicable. Use the
[Go representative chain](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/representative-chain)
and [Go multi-agent example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/multiagent).
The wrapper path itself is covered by the bridge tests:
`go test ./cmd/praxo-bridge/...`.
