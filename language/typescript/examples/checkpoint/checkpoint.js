const { Allowlist } = require("@axisvela/praxo-core");

class MemoryStore {
  constructor() {
    this.records = new Map();
  }

  save(record) {
    this.records.set(record.sessionId, record);
  }

  load(sessionId) {
    return this.records.get(sessionId);
  }
}

function defaultAllowlist() {
  const allowlist = new Allowlist();
  allowlist.register("order", () => ({ session_id: "", items: [] }));
  return allowlist;
}

function saveCheckpoint(store, allowlist, sessionId, version, items) {
  const payload = allowlist.marshal("order", { session_id: sessionId, items });
  const record = { id: `cp-${version}`, sessionId, version, payload };
  store.save(record);
  return record;
}

module.exports = {
  MemoryStore,
  defaultAllowlist,
  saveCheckpoint,
};
