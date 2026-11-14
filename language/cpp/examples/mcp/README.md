# MCP

This example uses a caller-owned in-process transport with the C++ MCP client.
It covers initialize, `tools/list`, and `tools/call` without a server process.

```bash
g++ -std=c++20 -I language/cpp/include language/cpp/examples/mcp/main.cpp \
  language/cpp/build/libpraxo_cpp.a -o build/cpp-mcp
./build/cpp-mcp
```

Expected output:

```text
C++ MCP example passed
```
