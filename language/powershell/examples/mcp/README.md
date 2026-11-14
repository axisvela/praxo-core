# MCP

The PowerShell Core does not bundle an MCP client. This example provides a
transport-neutral MCP-shaped client boundary: initialize, `tools/list`, and
`tools/call` over a caller-owned transport.

```powershell
powershell -File language/powershell/examples/mcp/mcp.ps1
```

Expected output:

```text
PowerShell MCP example passed
```
