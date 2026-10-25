# Shell Bridge

Thin wrapper over `praxo-bridge` following `spec/bridge.md`.

```bash
echo '{"content":"echo.run {\"text\":\"hi\"}"}' | ./shell/praxo-bridge.sh toolcall parse
echo '{"prompt":"hello"}' | PRAXO_BASE_URL=http://localhost:11434/v1 ./shell/praxo-bridge.sh run
```

Set `PRAXO_BRIDGE_BIN` to use a prebuilt binary. Otherwise the wrapper runs
`go run ./cmd/praxo-bridge`.

The wrapper preserves stdout JSON, stderr diagnostics, and the bridge exit
codes. Do not interpolate untrusted JSON into shell commands.
