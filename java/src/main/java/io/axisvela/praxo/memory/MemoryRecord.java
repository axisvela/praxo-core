package io.axisvela.praxo.memory;

import java.util.Map;

public record MemoryRecord(
        String id,
        String frame,
        String content,
        Map<String, Object> metadata,
        String createdAt) {

    public static final String EVENT = "event";
    public static final String DECISION = "decision";
    public static final String EXPERIENCE = "experience";
    public static final String PROCEDURE = "procedure";
    public static final String WORKSPACE_STATE = "workspace_state";
    public static final String CONSTRAINT = "constraint";
    public static final String INTENTION = "intention";
}
