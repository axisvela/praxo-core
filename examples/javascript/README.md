# PRAXO-CORE JavaScript Sample

JavaScript consumes the TypeScript SDK; it is a sample, not a second contract
implementation. The TypeScript package compiles to CommonJS and works from Node
20+.

## Build and run

```bash
cd language/typescript
npm ci
npm run build
cd ../..
node examples/javascript/sample.mjs
```

## Usage

```js
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const praxo = require("../../language/typescript/dist/index.js");

const model = {
  async generate() {
    return { message: { role: "assistant", content: "hello" } };
  },
};

const agent = new praxo.Agent({ model, maxSteps: 4 });
const result = await agent.run({ id: "demo", messages: [] }, "hello");
console.log(result.output);
```

Tools, middleware, memory, checkpoints, policy, and streaming are the same
TypeScript APIs; do not create a separate JavaScript core.

## Release

No separate tag. JavaScript ships with the TypeScript package
`typescript/v0.1.0`.
