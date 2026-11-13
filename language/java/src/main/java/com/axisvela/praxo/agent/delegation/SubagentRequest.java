package com.axisvela.praxo.agent.delegation;

import com.axisvela.praxo.model.Message;

import java.util.List;
import java.util.Map;

public record SubagentRequest(
        String parentSessionId,
        String agentId,
        String prompt,
        Map<String, Object> context,
        SubagentMode mode,
        List<Message> history) {

    public SubagentRequest {
        context = context == null ? Map.of() : Map.copyOf(context);
        mode = mode == null ? SubagentMode.ISOLATED : mode;
        history = history == null ? List.of() : List.copyOf(history);
    }
}
