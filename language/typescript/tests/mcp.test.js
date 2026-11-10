const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  McpCancelledError,
  McpClient,
  McpProtocolError,
  McpTimeoutError,
  McpToolError,
  McpTransportError,
  Registry,
  registerMcpTools,
} = require("../dist");

const server = path.join(__dirname, "fake-mcp-server.js");

async function start(scenario = "tools") {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "praxo-mcp-"));
  const marker = path.join(dir, "marker.txt");
  const client = await McpClient.connect({
    command: process.execPath,
    args: [server, scenario, marker],
    timeoutMs: 2000,
  });
  return { client, marker, dir };
}

function cleanup(t, client, dir) {
  t.after(async () => {
    await client.close();
    fs.rmSync(dir, { recursive: true, force: true });
  });
}

function markerText(marker) {
  return fs.existsSync(marker) ? fs.readFileSync(marker, "utf8") : "";
}

async function waitFor(predicate, timeout = 2000) {
  const started = Date.now();
  while (Date.now() - started < timeout) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error("timed out waiting for condition");
}

test("MCP client performs handshake and lists paginated tools", async (t) => {
  const { client, dir } = await start();
  cleanup(t, client, dir);
  assert.equal(client.ready, true);
  assert.equal(client.protocolVersion, "2024-11-05");
  assert.equal(typeof client.pid, "number");
  const tools = await client.listTools();
  assert.deepEqual(
    tools.map((tool) => tool.name),
    ["echo", "text", "fail", "later"]
  );
  assert.deepEqual(tools[0].inputSchema, {
    type: "object",
    properties: { text: { type: "string" } },
    required: ["text"],
  });
});

test("MCP client rejects repeated tool pagination cursors", async (t) => {
  const { client, dir } = await start("repeated-cursor");
  cleanup(t, client, dir);
  await assert.rejects(client.listTools(), (error) => {
    assert.ok(error instanceof McpProtocolError);
    assert.equal(error.code, "MCP_PROTOCOL");
    assert.match(error.message, /repeated tool pagination cursor/);
    return true;
  });
});

test("MCP client rejects duplicate tool names", async (t) => {
  const { client, dir } = await start("duplicate");
  cleanup(t, client, dir);
  await assert.rejects(client.listTools(), (error) => {
    assert.ok(error instanceof McpProtocolError);
    assert.equal(error.code, "MCP_PROTOCOL");
    assert.match(error.message, /duplicate tool dup/);
    return true;
  });
});

test("MCP client maps structured and text tool results", async (t) => {
  const { client, dir } = await start();
  cleanup(t, client, dir);
  assert.deepEqual(await client.callTool("echo", { text: "hi" }), {
    args: { text: "hi" },
  });
  assert.deepEqual(await client.callTool("text"), ["first", "second"]);
});

test("MCP client reports a tool error result", async (t) => {
  const { client, dir } = await start();
  cleanup(t, client, dir);
  await assert.rejects(client.callTool("fail"), (error) => {
    assert.ok(error instanceof McpToolError);
    assert.equal(error.code, "MCP_TOOL_ERROR");
    assert.match(error.message, /boom/);
    return true;
  });
});

test("MCP client closes the child process and refuses later calls", async (t) => {
  const { client, marker, dir } = await start();
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const pid = client.pid;
  await client.close();
  assert.equal(client.closed, true);
  await waitFor(() => markerText(marker).includes("exit"));
  await client.close();
  assert.equal(client.closed, true);
  await assert.rejects(client.listTools(), (error) => {
    assert.ok(error instanceof McpTransportError);
    assert.equal(error.code, "MCP_TRANSPORT");
    return true;
  });
  if (typeof pid === "number") {
    await waitFor(() => {
      try {
        process.kill(pid, 0);
        return false;
      } catch {
        return true;
      }
    });
  }
});

test("MCP client times out and sends a cancellation notification", async (t) => {
  const { client, marker, dir } = await start("hang");
  cleanup(t, client, dir);
  const tools = await client.listTools();
  assert.deepEqual(
    tools.map((tool) => tool.name),
    ["hang"]
  );
  await assert.rejects(
    client.callTool("hang", {}, { timeoutMs: 100 }),
    (error) => {
      assert.ok(error instanceof McpTimeoutError);
      assert.equal(error.code, "MCP_TIMEOUT");
      assert.match(error.message, /timed out/);
      return true;
    }
  );
  await waitFor(() => /cancelled:\d+/.test(markerText(marker)));
});

test("MCP client cancels an in-flight request from an AbortSignal", async (t) => {
  const { client, marker, dir } = await start("hang");
  cleanup(t, client, dir);
  await client.listTools();
  const controller = new AbortController();
  const call = client.callTool(
    "hang",
    {},
    { signal: controller.signal, timeoutMs: 0 }
  );
  setTimeout(() => controller.abort(), 50);
  await assert.rejects(call, (error) => {
    assert.ok(error instanceof McpCancelledError);
    assert.equal(error.code, "MCP_CANCELLED");
    return true;
  });
  await waitFor(() => markerText(marker).includes("cancelled:"));
});

test("MCP helper registers tools in the Core registry", async (t) => {
  const { client, dir } = await start();
  cleanup(t, client, dir);
  const registry = new Registry();
  const adapters = registerMcpTools(registry, client, await client.listTools());
  assert.equal(registry.size, 4);
  assert.deepEqual(
    adapters.map((tool) => tool.name),
    ["echo", "text", "fail", "later"]
  );
  assert.deepEqual(adapters[0].spec(), {
    name: "echo",
    description: "Echo",
    parameters: {
      type: "object",
      properties: { text: { type: "string" } },
      required: ["text"],
    },
  });
  assert.deepEqual(await registry.get("echo").invoke({ text: "hi" }), {
    args: { text: "hi" },
  });
});
