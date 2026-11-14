# MCP

This example uses a caller-owned in-process transport with the C MCP client. It
covers initialize, `tools/list`, and `tools/call` without a server process.

```bash
gcc -std=c11 -I language/c/include -I language/c/src language/c/examples/mcp/main.c \
  language/c/src/mcp.c language/c/build/libpraxo_core.a -o build/c-mcp
./build/c-mcp
```

Expected output:

```text
C MCP example passed
```
