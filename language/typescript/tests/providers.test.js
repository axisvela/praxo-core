const assert = require("node:assert/strict");
const http = require("node:http");
const test = require("node:test");

const {
  AnthropicModel,
  GeminiModel,
  PROVIDER_BASE_URLS,
  openAICompatibleConfig,
} = require("../dist");

const ANTHROPIC = {
  content: [
    { type: "text", text: "hello" },
    { type: "tool_use", id: "tool-1", name: "echo", input: { text: "hi" } },
  ],
  stop_reason: "end_turn",
  usage: {
    input_tokens: 3,
    output_tokens: 4,
    cache_read_input_tokens: 2,
  },
};

const ANTHROPIC_STREAM = [
  { type: "message_start", message: { usage: { input_tokens: 3 } } },
  {
    type: "content_block_start",
    index: 0,
    content_block: { type: "text", text: "" },
  },
  {
    type: "content_block_delta",
    index: 0,
    delta: { type: "text_delta", text: "he" },
  },
  {
    type: "content_block_delta",
    index: 0,
    delta: { type: "text_delta", text: "llo" },
  },
  {
    type: "content_block_start",
    index: 1,
    content_block: {
      type: "tool_use",
      id: "tool-1",
      name: "echo",
      input: {},
    },
  },
  {
    type: "content_block_delta",
    index: 1,
    delta: { type: "input_json_delta", partial_json: '{"text":' },
  },
  {
    type: "content_block_delta",
    index: 1,
    delta: { type: "input_json_delta", partial_json: '"hi"}' },
  },
  {
    type: "message_delta",
    delta: { stop_reason: "end_turn" },
    usage: { output_tokens: 4 },
  },
  { type: "message_stop" },
];

const GEMINI = {
  candidates: [
    {
      content: {
        role: "model",
        parts: [
          { text: "hello" },
          { functionCall: { name: "echo", args: { text: "hi" } } },
        ],
      },
      finishReason: "STOP",
    },
  ],
  usageMetadata: {
    promptTokenCount: 3,
    candidatesTokenCount: 4,
    cachedContentTokenCount: 2,
  },
};

const GEMINI_STREAM = [
  { candidates: [{ content: { parts: [{ text: "he" }] } }] },
  { candidates: [{ content: { parts: [{ text: "llo" }] } }] },
  {
    candidates: [
      {
        content: {
          parts: [{ functionCall: { name: "echo", args: { text: "hi" } } }],
        },
        finishReason: "STOP",
      },
    ],
    usageMetadata: { promptTokenCount: 3, candidatesTokenCount: 4 },
  },
];

function startServer(state) {
  return new Promise((resolve) => {
    const server = http.createServer((request, response) => {
      let body = "";
      request.on("data", (chunk) => {
        body += chunk;
      });
      request.on("end", () => {
        const payload = JSON.parse(body || "{}");
        if (request.url.startsWith("/v1/messages")) {
          state.anthropicHeaders = request.headers;
          state.anthropicBody = payload;
          if (payload.stream) {
            emit(response, ANTHROPIC_STREAM);
          } else {
            json(response, ANTHROPIC);
          }
          return;
        }
        state.geminiHeaders = request.headers;
        state.geminiBody = payload;
        if (request.url.includes(":streamGenerateContent")) {
          emit(response, GEMINI_STREAM);
        } else {
          json(response, GEMINI);
        }
      });
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function json(response, payload) {
  response.writeHead(200, { "Content-Type": "application/json" });
  response.end(JSON.stringify(payload));
}

function emit(response, events) {
  response.writeHead(200, { "Content-Type": "text/event-stream" });
  for (const event of events) {
    response.write(`data: ${JSON.stringify(event)}\n\n`);
  }
  response.end();
}

function request() {
  return {
    messages: [
      { role: "system", content: "be brief" },
      { role: "user", content: "hi" },
    ],
    tools: [
      { name: "echo", description: "Echo", parameters: { type: "object" } },
    ],
    toolChoice: "auto",
    temperature: 0.2,
  };
}

test("Anthropic non-streaming generation", async (t) => {
  const state = {};
  const server = await startServer(state);
  t.after(() => server.close());
  const { port } = server.address();
  const model = new AnthropicModel({
    apiKey: "ak",
    model: "claude-test",
    baseUrl: `http://127.0.0.1:${port}`,
  });
  const response = await model.generate(request());
  assert.equal(response.message.content, "hello");
  assert.equal(response.message.toolCalls[0].id, "tool-1");
  assert.deepEqual(response.message.toolCalls[0].arguments, { text: "hi" });
  assert.equal(response.usage.cachedTokens, 2);
  assert.equal(response.finishReason, "end_turn");
  assert.equal(state.anthropicHeaders["x-api-key"], "ak");
  assert.equal(state.anthropicHeaders["anthropic-version"], "2023-06-01");
  assert.equal(state.anthropicBody.system, "be brief");
  assert.deepEqual(state.anthropicBody.tools[0].input_schema, {
    type: "object",
  });
  assert.deepEqual(state.anthropicBody.tool_choice, { type: "auto" });
});

test("Anthropic SSE streaming", async (t) => {
  const state = {};
  const server = await startServer(state);
  t.after(() => server.close());
  const { port } = server.address();
  const model = new AnthropicModel({
    apiKey: "ak",
    model: "claude-test",
    baseUrl: `http://127.0.0.1:${port}`,
  });
  const deltas = [];
  const response = await model.generateStream(request(), (delta) =>
    deltas.push(delta)
  );
  assert.deepEqual(deltas, ["he", "llo"]);
  assert.equal(response.message.content, "hello");
  assert.deepEqual(response.message.toolCalls[0].arguments, { text: "hi" });
  assert.equal(response.usage.outputTokens, 4);
});

test("Gemini non-streaming generation", async (t) => {
  const state = {};
  const server = await startServer(state);
  t.after(() => server.close());
  const { port } = server.address();
  const model = new GeminiModel({
    apiKey: "gk",
    model: "gemini-test",
    baseUrl: `http://127.0.0.1:${port}`,
  });
  const response = await model.generate(request());
  assert.equal(response.message.content, "hello");
  assert.equal(response.message.toolCalls[0].name, "echo");
  assert.deepEqual(response.message.toolCalls[0].arguments, { text: "hi" });
  assert.equal(response.usage.inputTokens, 3);
  assert.equal(response.finishReason, "STOP");
  assert.equal(state.geminiHeaders["x-goog-api-key"], "gk");
  assert.deepEqual(state.geminiBody.system_instruction, {
    parts: [{ text: "be brief" }],
  });
  assert.equal(
    state.geminiBody.toolConfig.functionCallingConfig.mode,
    "AUTO"
  );
});

test("Gemini SSE streaming", async (t) => {
  const state = {};
  const server = await startServer(state);
  t.after(() => server.close());
  const { port } = server.address();
  const model = new GeminiModel({
    apiKey: "gk",
    model: "gemini-test",
    baseUrl: `http://127.0.0.1:${port}`,
  });
  const deltas = [];
  const response = await model.generateStream(request(), (delta) =>
    deltas.push(delta)
  );
  assert.deepEqual(deltas, ["he", "llo"]);
  assert.deepEqual(response.message.toolCalls[0].arguments, { text: "hi" });
  assert.equal(response.finishReason, "STOP");
});

test("provider presets cover OpenAI-compatible providers", () => {
  assert.equal(
    openAICompatibleConfig("deepseek", "deepseek-chat").baseUrl,
    PROVIDER_BASE_URLS.deepseek
  );
  assert.equal(
    openAICompatibleConfig("kimi", "moonshot-v1-8k").baseUrl,
    PROVIDER_BASE_URLS.kimi
  );
  assert.throws(() => openAICompatibleConfig("unknown", "model"));
});
