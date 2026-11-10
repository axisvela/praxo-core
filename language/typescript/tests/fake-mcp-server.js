const fs = require("node:fs");
const readline = require("node:readline");

const scenario = process.argv[2] || "tools";
const marker = process.argv[3];

function mark(line) {
  if (!marker) return;
  try {
    fs.appendFileSync(marker, `${line}\n`);
  } catch {
    // A marker is diagnostic only; never fail the server on it.
  }
}

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function tool(name, description, inputSchema) {
  return {
    name,
    description,
    inputSchema: inputSchema || {
      type: "object",
      properties: {},
    },
  };
}

const pages = {
  tools: [
    {
      tools: [
        tool("echo", "Echo", {
          type: "object",
          properties: { text: { type: "string" } },
          required: ["text"],
        }),
        tool("text", "Text"),
        tool("fail", "Fail"),
      ],
      nextCursor: "page-2",
    },
    {
      tools: [tool("later", "Later")],
    },
  ],
  "repeated-cursor": [
    { tools: [tool("echo", "Echo")], nextCursor: "loop" },
    { tools: [tool("later", "Later")], nextCursor: "loop" },
  ],
  duplicate: [
    {
      tools: [tool("dup", "First"), tool("dup", "Second")],
    },
  ],
  hang: [{ tools: [tool("hang", "Hang")] }],
};

function listResult(message) {
  const scenarioPages = pages[scenario] || pages.tools;
  const cursor = message.params && message.params.cursor;
  let index = 0;
  if (scenario === "tools" && cursor === "page-2") {
    index = 1;
  }
  if (scenario === "repeated-cursor" && cursor) {
    index = 1;
  }
  const page = scenarioPages[index] || { tools: [] };
  const result = { tools: page.tools };
  if (page.nextCursor !== undefined) {
    result.nextCursor = page.nextCursor;
  }
  send({ jsonrpc: "2.0", id: message.id, result });
}

function callResult(message) {
  const name = message.params && message.params.name;
  const args = (message.params && message.params.arguments) || {};
  if (name === "echo") {
    send({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        content: [{ type: "text", text: "echo text" }],
        structuredContent: { args },
      },
    });
    return;
  }
  if (name === "text") {
    send({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        content: [
          { type: "text", text: "first" },
          { type: "text", text: "second" },
        ],
      },
    });
    return;
  }
  if (name === "fail") {
    send({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        isError: true,
        content: [{ type: "text", text: "boom" }],
      },
    });
    return;
  }
  if (name === "hang" || scenario === "hang") {
    mark("hanging");
    return;
  }
  send({
    jsonrpc: "2.0",
    id: message.id,
    result: { content: [] },
  });
}

const input = readline.createInterface({ input: process.stdin });
input.on("line", (line) => {
  if (!line.trim()) return;
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }
  if (message.method === "initialize") {
    send({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "fake-mcp", version: "0.0.0" },
      },
    });
    return;
  }
  if (message.method === "notifications/initialized") {
    mark("initialized");
    return;
  }
  if (message.method === "notifications/cancelled") {
    mark(`cancelled:${message.params && message.params.requestId}`);
    return;
  }
  if (message.method === "tools/list") {
    listResult(message);
    return;
  }
  if (message.method === "tools/call") {
    mark(`call:${message.params && message.params.name}`);
    callResult(message);
    return;
  }
  if (message.id !== undefined) {
    send({
      jsonrpc: "2.0",
      id: message.id,
      error: { code: -32601, message: "method not found" },
    });
  }
});
input.on("close", () => {
  mark("exit");
  process.exit(0);
});
process.on("SIGTERM", () => {
  mark("exit");
  process.exit(0);
});
process.on("SIGINT", () => {
  mark("exit");
  process.exit(0);
});
