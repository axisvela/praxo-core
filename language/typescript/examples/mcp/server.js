const readline = require("node:readline");

const TOOLS = [
  {
    name: "echo",
    description: "Echo input",
    inputSchema: {
      type: "object",
      properties: { text: { type: "string" } },
      required: ["text"],
    },
  },
  {
    name: "add",
    description: "Add two integers",
    inputSchema: {
      type: "object",
      properties: { a: { type: "integer" }, b: { type: "integer" } },
      required: ["a", "b"],
    },
  },
];

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function respond(id, result) {
  send({ jsonrpc: "2.0", id, result });
}

function callTool(params) {
  const name = params && params.name;
  const args = (params && params.arguments) || {};
  if (name === "echo") {
    return {
      content: [{ type: "text", text: String(args.text || "") }],
      isError: false,
    };
  }
  if (name === "add") {
    const sum = Number(args.a || 0) + Number(args.b || 0);
    return {
      content: [{ type: "text", text: String(sum) }],
      structuredContent: { sum },
      isError: false,
    };
  }
  return {
    content: [{ type: "text", text: `unknown tool ${name}` }],
    isError: true,
  };
}

let initialized = false;
readline.createInterface({ input: process.stdin }).on("line", (line) => {
  if (!line.trim()) return;
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }
  if (message.method === "initialize") {
    respond(message.id, {
      protocolVersion: "2024-11-05",
      capabilities: { tools: {} },
      serverInfo: { name: "example-mcp", version: "1.0.0" },
    });
  } else if (message.method === "notifications/initialized") {
    initialized = true;
  } else if (message.method === "tools/list" && initialized) {
    respond(message.id, { tools: TOOLS });
  } else if (message.method === "tools/call" && initialized) {
    respond(message.id, callTool(message.params));
  } else if (message.id !== undefined) {
    send({
      jsonrpc: "2.0",
      id: message.id,
      error: { code: -32601, message: "method not found" },
    });
  }
});
