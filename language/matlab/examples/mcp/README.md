# MCP

The MATLAB/Octave Core does not bundle an MCP client. This example provides a
transport-neutral MCP-shaped client boundary: initialize, `tools/list`, and
`tools/call` over a caller-owned transport.

```bash
octave-cli --path language/matlab/examples/mcp --eval mcp_example
```

Expected output:

```text
MATLAB MCP example passed
```
