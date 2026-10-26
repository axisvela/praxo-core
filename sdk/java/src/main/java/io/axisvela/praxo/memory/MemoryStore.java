package io.axisvela.praxo.memory;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

public final class MemoryStore implements Store {
    private record Stored(MemoryRecord record, String search) {
    }

    private final Map<String, List<Stored>> records = new LinkedHashMap<>();

    @Override
    public synchronized void put(String sessionId, MemoryRecord record) {
        String id = record.id();
        if (id == null || id.isEmpty()) {
            id = "mem-" + UUID.randomUUID().toString().replace("-", "");
        }
        String createdAt = record.createdAt();
        if (createdAt == null || createdAt.isEmpty()) {
            createdAt = Instant.now().toString();
        }
        MemoryRecord stored = new MemoryRecord(
                id, record.frame(), record.content(), record.metadata(), createdAt);
        records.computeIfAbsent(sessionId, key -> new ArrayList<>())
                .add(new Stored(stored, stored.content().toLowerCase(Locale.ROOT)));
    }

    @Override
    public synchronized List<MemoryRecord> search(
            String sessionId, String query, int limit) {
        String needle = query == null ? "" : query.trim().toLowerCase(Locale.ROOT);
        List<MemoryRecord> out = new ArrayList<>();
        for (Stored item : records.getOrDefault(sessionId, List.of())) {
            if (needle.isEmpty() || item.search().contains(needle)) {
                out.add(item.record());
            }
        }
        out.sort(Comparator.comparing(
                record -> Instant.parse(record.createdAt()),
                Comparator.reverseOrder()));
        if (limit > 0 && out.size() > limit) {
            return new ArrayList<>(out.subList(0, limit));
        }
        return out;
    }
}
