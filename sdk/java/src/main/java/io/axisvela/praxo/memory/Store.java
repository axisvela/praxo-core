package io.axisvela.praxo.memory;

import java.util.List;

public interface Store {
    void put(String sessionId, MemoryRecord record) throws Exception;

    List<MemoryRecord> search(String sessionId, String query, int limit)
            throws Exception;
}
