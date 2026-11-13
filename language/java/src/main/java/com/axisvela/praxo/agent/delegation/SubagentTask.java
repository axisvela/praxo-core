package com.axisvela.praxo.agent.delegation;

import java.time.Instant;

public record SubagentTask(
        String id,
        String parentSessionId,
        String agentId,
        SubagentMode mode,
        SubagentStatus status,
        String output,
        String error,
        Instant createdAt,
        Instant updatedAt) {

    public SubagentTask {
        output = output == null ? "" : output;
        error = error == null ? "" : error;
    }
}
