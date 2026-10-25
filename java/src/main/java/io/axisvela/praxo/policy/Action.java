package io.axisvela.praxo.policy;

import java.util.Map;

public record Action(
        String kind,
        String sessionId,
        String toolName,
        Map<String, Object> arguments) {
    public static Action of(String kind, String sessionId) {
        return new Action(kind, sessionId, null, null);
    }
}
