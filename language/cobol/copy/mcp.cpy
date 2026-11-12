       01 px-mcp-options.
          05 px-mcp-op pic x(16).
          05 px-mcp-transport-program pic x(64).
          05 px-mcp-client-version pic x(32).
          05 px-mcp-protocol-version pic x(32).
          05 px-mcp-tool-name pic x(64).
          05 px-mcp-tool-name-length binary-long.
          05 px-mcp-arguments pic x(4096).
          05 px-mcp-arguments-length binary-long.
       01 px-mcp-result.
          05 px-mcp-output pic x(16384).
          05 px-mcp-output-length binary-long.
          05 px-mcp-protocol pic x(32).
          05 px-mcp-protocol-length binary-long.
          05 px-mcp-server-info pic x(2048).
          05 px-mcp-server-info-length binary-long.
