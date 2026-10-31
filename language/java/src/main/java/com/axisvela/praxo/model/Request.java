package com.axisvela.praxo.model;

import java.util.ArrayList;
import java.util.List;

public record Request(
        String model,
        List<Message> messages,
        List<ToolSpec> tools,
        String toolChoice,
        ResponseFormat responseFormat,
        CacheHint cacheHint,
        double temperature) {

    public Request {
        messages = messages == null ? List.of() : messages;
        tools = tools == null ? List.of() : tools;
    }

    public static Request of(List<Message> messages) {
        return new Request(null, new ArrayList<>(messages), List.of(), null, null, null, 0);
    }

    public Request withTools(List<ToolSpec> value) {
        return new Request(model, messages, value, toolChoice, responseFormat,
                cacheHint, temperature);
    }
}
