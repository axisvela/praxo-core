package com.axisvela.praxo.agent.delegation;

import com.axisvela.praxo.model.Usage;

public record SubagentResult(
        String taskId,
        String agentId,
        String output,
        Usage usage) {
}
