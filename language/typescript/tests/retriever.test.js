const assert = require("node:assert/strict");
const test = require("node:test");

const { FuncRetriever } = require("../dist");

test("function retriever forwards query and limit", async () => {
  const retriever = new FuncRetriever(async (query, limit) => [
    { id: "doc-1", content: `${query}:${limit}`, score: 0.5 },
  ]);
  const documents = await retriever.retrieve("hello", 3);
  assert.equal(documents.length, 1);
  assert.equal(documents[0].id, "doc-1");
  assert.equal(documents[0].content, "hello:3");
  assert.equal(documents[0].score, 0.5);
});
