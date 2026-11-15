# MCP

This example uses a caller-owned in-process transport with the Objective-C MCP
client.

```bash
clang -fobjc-arc -Ilanguage/objc/src \
  language/objc/examples/mcp/mcp.m language/objc/src/PraxoMCP.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoJSON.m \
  -framework Foundation -o build/objc-mcp
./build/objc-mcp
```

Expected output:

```text
Objective-C MCP example passed
```
