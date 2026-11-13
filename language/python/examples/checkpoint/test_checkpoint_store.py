import unittest

from praxo.errors import TypeNotAllowedError

from checkpoint_store import MemoryStore, default_allowlist, save_checkpoint


class CheckpointStoreTests(unittest.TestCase):
    def test_latest_checkpoint_round_trips(self):
        allowlist = default_allowlist()
        store = MemoryStore()
        save_checkpoint(store, allowlist, "session-1", 1, ["book"])
        save_checkpoint(store, allowlist, "session-1", 2, ["book", "pen"])

        loaded = store.load("session-1")
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded.version, 2)
        payload = allowlist.unmarshal(loaded.payload)
        self.assertEqual(payload["session_id"], "session-1")
        self.assertEqual(payload["items"], ["book", "pen"])

    def test_unregistered_payload_type_is_rejected(self):
        allowlist = default_allowlist()
        with self.assertRaises(TypeNotAllowedError):
            allowlist.marshal("unknown", {"session_id": "session-1"})


if __name__ == "__main__":
    unittest.main()
