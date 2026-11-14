# MCP

This example uses a caller-owned in-process transport with the Zig MCP client.

```bash
zig build-exe language/zig/examples/mcp/mcp.zig \
  --dep json --dep mcp \
  -Mroot=language/zig/examples/mcp/mcp.zig \
  -Mjson=language/zig/src/json.zig -Mmcp=language/zig/src/mcp.zig \
  -femit-bin=build/zig-mcp
./build/zig-mcp
```

Expected output:

```text
Zig MCP example passed
```
