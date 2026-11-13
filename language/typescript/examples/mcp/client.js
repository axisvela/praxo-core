const path = require("node:path");
const {
  McpClient,
  Registry,
  registerMcpTools,
} = require("@axisvela/praxo-core");

async function demo() {
  const client = await McpClient.connect({
    command: process.execPath,
    args: [path.join(__dirname, "server.js")],
    timeoutMs: 5000,
  });
  try {
    const tools = await client.listTools();
    const registry = new Registry();
    registerMcpTools(registry, client, tools);
    const result = await client.callTool("add", { a: 2, b: 3 });
    return `tools=${tools
      .map((tool) => tool.name)
      .sort()
      .join(",")}; sum=${result.sum}`;
  } finally {
    await client.close();
  }
}

async function main() {
  try {
    console.log(await demo());
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

if (require.main === module) {
  main();
}

module.exports = { demo };
