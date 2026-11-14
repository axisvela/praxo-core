# MCP

This example uses a caller-owned in-process transport with the Objective-C MCP
client.

```bash
clang -fobjc-arc -Ilanguage/objc \
  language/objc/examples/mcp/mcp.m language/objc/PraxoMCP.m \
  language/objc/PraxoCore.m language/objc/PraxoJSON.m \
  -framework Foundation -o build/objc-mcp
./build/objc-mcp
```

Expected output:

```text
Objective-C MCP example passed
```
