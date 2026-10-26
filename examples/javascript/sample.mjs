import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const praxo = require("../../sdk/typescript/dist/index.js");

const model = {
  async generate() {
    return { message: { role: "assistant", content: "hello from JavaScript" } };
  },
};

const registry = new praxo.Registry();
registry.register(
  new praxo.FuncTool("echo", "Echo arguments", (arguments_) => arguments_),
);

const agent = new praxo.Agent({
  model,
  tools: registry,
  maxSteps: 4,
});

const result = await agent.run({ id: "demo", messages: [] }, "hello");
if (result.output !== "hello from JavaScript") {
  throw new Error(`unexpected output: ${result.output}`);
}
console.log(result.output);
