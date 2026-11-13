const test = require("node:test");
const assert = require("node:assert/strict");

const { TypeNotAllowedError } = require("@axisvela/praxo-core");
const {
  MemoryStore,
  defaultAllowlist,
  saveCheckpoint,
} = require("./checkpoint");

test("latest checkpoint round trips", () => {
  const allowlist = defaultAllowlist();
  const store = new MemoryStore();
  saveCheckpoint(store, allowlist, "session-1", 1, ["book"]);
  saveCheckpoint(store, allowlist, "session-1", 2, ["book", "pen"]);

  const loaded = store.load("session-1");
  assert.equal(loaded.version, 2);
  const payload = allowlist.unmarshal(loaded.payload);
  assert.equal(payload.session_id, "session-1");
  assert.deepEqual(payload.items, ["book", "pen"]);
});

test("unregistered payload type is rejected", () => {
  const allowlist = defaultAllowlist();
  assert.throws(
    () => allowlist.marshal("unknown", { session_id: "session-1" }),
    TypeNotAllowedError
  );
});
