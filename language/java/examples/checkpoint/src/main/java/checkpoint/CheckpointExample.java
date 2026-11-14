package checkpoint;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.checkpoint.Allowlist;
import com.axisvela.praxo.util.Json;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class CheckpointExample {
    private CheckpointExample() {
    }

    record CheckpointRecord(String id, String sessionId, int version, String payload) {
    }

    static final class MemoryStore {
        private final Map<String, CheckpointRecord> records = new LinkedHashMap<>();

        void save(CheckpointRecord record) {
            records.put(record.sessionId(), record);
        }

        CheckpointRecord load(String sessionId) {
            return records.get(sessionId);
        }
    }

    static Allowlist defaultAllowlist() {
        Allowlist allowlist = new Allowlist();
        allowlist.register("order", () -> {
            Map<String, Object> value = new LinkedHashMap<>();
            value.put("session_id", "");
            value.put("items", List.of());
            return value;
        });
        return allowlist;
    }

    static void saveCheckpoint(
            MemoryStore store, Allowlist allowlist, String sessionId, int version, List<String> items) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("session_id", sessionId);
        payload.put("items", items);
        String encoded = allowlist.marshal("order", payload);
        store.save(new CheckpointRecord(
                "cp-" + version, sessionId, version, encoded));
    }

    @SuppressWarnings("unchecked")
    public static void main(String[] args) {
        Allowlist allowlist = defaultAllowlist();
        MemoryStore store = new MemoryStore();
        saveCheckpoint(store, allowlist, "session-1", 1, List.of("book"));
        saveCheckpoint(store, allowlist, "session-1", 2, List.of("book", "pen"));

        CheckpointRecord loaded = store.load("session-1");
        if (loaded == null || loaded.version() != 2) {
            throw new IllegalStateException("latest checkpoint was not loaded");
        }
        Map<String, Object> payload = (Map<String, Object>) allowlist.unmarshal(loaded.payload());
        if (!"session-1".equals(payload.get("session_id"))
                || !List.of("book", "pen").equals(payload.get("items"))) {
            throw new IllegalStateException("payload did not round trip: " + payload);
        }

        try {
            allowlist.marshal("unknown", Json.object("{\"session_id\":\"session-1\"}"));
        } catch (PraxoException error) {
            if ("CHECKPOINT_TYPE_NOT_ALLOWED".equals(error.code)) {
                System.out.println("checkpoint test: ok");
                return;
            }
            throw error;
        }
        throw new IllegalStateException("unregistered payload type was accepted");
    }
}
