const assert = require("node:assert/strict");
const http = require("node:http");
const test = require("node:test");

const {
  McpClient,
  McpStreamableHTTPTransport,
  McpTransportError,
} = require("../dist");

async function startServer() {
  const state = { requests: [], deleted: false, sse: false };
  const server = http.createServer((req, res) => {
    if (req.method === "DELETE") {
      state.deleted = true;
      res.writeHead(200);
      res.end();
      return;
    }
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      const message = JSON.parse(body);
      state.requests.push({ message, headers: req.headers });
      if (message.method === "initialize") {
        res.writeHead(200, {
          "content-type": "application/json",
          "mcp-session-id": "sess-1",
        });
        res.end(
          JSON.stringify({
            jsonrpc: "2.0",
            id: message.id,
            result: {
              protocolVersion: "2025-03-26",
              capabilities: { tools: {} },
              serverInfo: { name: "fake-http", version: "1" },
            },
          })
        );
        return;
      }
      if (message.method?.startsWith("notifications/")) {
        res.writeHead(202);
        res.end();
        return;
      }
      if (message.method === "tools/list") {
        res.writeHead(200, { "content-type": "application/json" });
        res.end(
          JSON.stringify({
            jsonrpc: "2.0",
            id: message.id,
            result: {
              tools: [
                {
                  name: "echo",
                  description: "Echo input",
                  inputSchema: {
                    type: "object",
                    properties: { text: { type: "string" } },
                    required: ["text"],
                  },
                },
              ],
            },
          })
        );
        return;
      }
      if (message.method === "tools/call") {
        const result = {
          jsonrpc: "2.0",
          id: message.id,
          result: { content: [{ type: "text", text: "http-ok" }] },
        };
        if (state.sse) {
          res.writeHead(200, { "content-type": "text/event-stream" });
          res.end(`event: message\ndata: ${JSON.stringify(result)}\n\n`);
        } else {
          res.writeHead(200, { "content-type": "application/json" });
          res.end(JSON.stringify(result));
        }
        return;
      }
      res.writeHead(200, { "content-type": "application/json" });
      res.end(
        JSON.stringify({
          jsonrpc: "2.0",
          id: message.id,
          result: {},
        })
      );
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return {
    state,
    server,
    endpoint: `http://127.0.0.1:${server.address().port}/mcp`,
  };
}

test("Streamable HTTP MCP handshake, tools, call, and DELETE", async () => {
  const { state, server, endpoint } = await startServer();
  const transport = new McpStreamableHTTPTransport({ endpoint });
  const client = await McpClient.connect({
    transport,
    protocolVersion: "2025-03-26",
    timeoutMs: 2000,
  });
  try {
    assert.equal(client.protocolVersion, "2025-03-26");
    const tools = await client.listTools();
    assert.deepEqual(tools.map((tool) => tool.name), ["echo"]);
    const result = await client.callTool("echo", { text: "hi" });
    assert.equal(result, "http-ok");
  } finally {
    await client.close();
    await new Promise((resolve) => server.close(resolve));
  }
  const listed = state.requests.find(
    (item) => item.message.method === "tools/list"
  );
  assert.equal(listed.headers["mcp-session-id"], "sess-1");
  assert.equal(listed.headers["mcp-protocol-version"], "2025-03-26");
  assert.equal(state.deleted, true);
});

test("Streamable HTTP parses SSE responses", async () => {
  const { state, server, endpoint } = await startServer();
  state.sse = true;
  const transport = new McpStreamableHTTPTransport({ endpoint });
  const client = await McpClient.connect({
    transport,
    protocolVersion: "2025-03-26",
    timeoutMs: 2000,
  });
  try {
    assert.equal(await client.callTool("echo", { text: "hi" }), "http-ok");
  } finally {
    await client.close();
    await new Promise((resolve) => server.close(resolve));
  }
});

test("Streamable HTTP rejects remote plain HTTP", () => {
  assert.throws(
    () =>
      new McpStreamableHTTPTransport({
        endpoint: "http://example.com/mcp",
      }),
    (error) => {
      assert.ok(error instanceof McpTransportError);
      assert.match(error.message, /HTTPS/);
      return true;
    }
  );
});
