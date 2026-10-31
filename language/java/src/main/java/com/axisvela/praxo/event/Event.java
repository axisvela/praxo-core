package com.axisvela.praxo.event;

import java.util.Map;

public record Event(
        String type,
        String sessionId,
        String runId,
        Map<String, Object> data,
        String at) {
}
