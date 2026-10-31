const assert = require("node:assert/strict");
const http = require("node:http");
const test = require("node:test");

const {
  AbortError,
  OpenAICompatibleModel,
} = require("../dist");

function startServer() {
  return new Promise((resolve) => {
    const server = http.createServer((request, response) => {
      let body = "";
      request.on("data", (chunk) => {
        body += chunk;
      });
      request.on("end", () => {
        const payload = JSON.parse(body || "{}");
        const messages = payload.messages || [];
        const prompt = messages.length
          ? messages[messages.length - 1].content
          : undefined;
        if (payload.stream) {
          response.writeHead(200, {
            "Content-Type": "text/event-stream",
          });
          if (prompt === "truncate") {
            response.end(
              'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n'
            );
            return;
          }
          if (prompt === "half") {
            response.end('data: {"choices":[{"delta":');
            return;
          }
          const chunks = [
            { choices: [{ delta: { role: "assistant", content: "he" } }] },
            { choices: [{ delta: { content: "llo" } }] },
            {
              choices: [
                {
                  delta: {
                    tool_calls: [
                      {
                        index: 0,
                        id: "c1",
                        function: {
                          name: "echo",
                          arguments: '{"text":',
                        },
                      },
                    ],
                  },
                },
              ],
            },
            {
              choices: [
                {
                  delta: {
                    tool_calls: [
                      { index: 0, function: { arguments: '"hi"}' } },
                    ],
                  },
                  finish_reason: "stop",
                },
              ],
            },
            {
              choices: [],
              usage: { prompt_tokens: 3, completion_tokens: 4 },
            },
          ];
          for (const chunk of chunks) {
            response.write(`data: ${JSON.stringify(chunk)}\n\n`);
          }
          response.end("data: [DONE]\n\n");
          return;
        }
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end(
          JSON.stringify({
            choices: [
              {
                message: {
                  role: "assistant",
                  content: "hello",
                  tool_calls: [
                    {
                      id: "c1",
                      function: {
                        name: "echo",
                        arguments: '{"text":"hi"}',
                      },
                    },
                  ],
                },
                finish_reason: "stop",
              },
            ],
            usage: { prompt_tokens: 3, completion_tokens: 4 },
          })
        );
      });
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

test("OpenAI-compatible non-streaming generation", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  const { port } = server.address();
  const model = new OpenAICompatibleModel({
    baseUrl: `http://127.0.0.1:${port}/v1`,
    apiKey: "k",
    model: "test",
  });
  const response = await model.generate({
    messages: [{ role: "user", content: "hi" }],
  });
  assert.equal(response.message.content, "hello");
  assert.equal(response.message.toolCalls[0].name, "echo");
  assert.deepEqual(response.message.toolCalls[0].arguments, { text: "hi" });
  assert.equal(response.usage.inputTokens, 3);
  assert.equal(response.usage.outputTokens, 4);
});

test("OpenAI-compatible SSE streaming", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  const { port } = server.address();
  const model = new OpenAICompatibleModel({
    baseUrl: `http://127.0.0.1:${port}/v1`,
    model: "test",
  });
  const deltas = [];
  const response = await model.generateStream(
    { messages: [{ role: "user", content: "hi" }] },
    (delta) => deltas.push(delta)
  );
  assert.deepEqual(deltas, ["he", "llo"]);
  assert.equal(response.message.content, "hello");
  assert.equal(response.message.toolCalls[0].name, "echo");
  assert.deepEqual(response.message.toolCalls[0].arguments, { text: "hi" });
  assert.equal(response.usage.outputTokens, 4);
});

test("OpenAI-compatible stream rejects truncation", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  const { port } = server.address();
  const model = new OpenAICompatibleModel({
    baseUrl: `http://127.0.0.1:${port}/v1`,
    model: "test",
  });
  await assert.rejects(
    model.generateStream(
      {
        messages: [{ role: "user", content: "truncate" }],
      },
      () => {}
    ),
    /stream ended before completion/
  );
});

test("OpenAI-compatible stream rejects half packet", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  const { port } = server.address();
  const model = new OpenAICompatibleModel({
    baseUrl: `http://127.0.0.1:${port}/v1`,
    model: "test",
  });
  await assert.rejects(
    model.generateStream(
      {
        messages: [{ role: "user", content: "half" }],
      },
      () => {}
    ),
    SyntaxError
  );
});

test("OpenAI-compatible adapter honors AbortSignal", async () => {
  const controller = new AbortController();
  controller.abort();
  const model = new OpenAICompatibleModel({
    baseUrl: "http://127.0.0.1:1/v1",
    model: "test",
  });
  await assert.rejects(
    model.generate({
      messages: [{ role: "user", content: "hi" }],
      signal: controller.signal,
    }),
    (error) => error instanceof AbortError
  );
});
