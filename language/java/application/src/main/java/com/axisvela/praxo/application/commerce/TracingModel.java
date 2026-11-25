package com.axisvela.praxo.application.commerce;

import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class TracingModel implements Model {
    private final Model inner;
    private final List<Map<String, Object>> steps = new ArrayList<>();

    public TracingModel(Model inner) {
        this.inner = inner;
    }

    @Override
    public Response generate(Request request) throws Exception {
        Response response;
        try {
            response = inner.generate(request);
        } catch (Exception error) {
            Map<String, Object> step = new LinkedHashMap<>();
            step.put("error", error.getMessage() == null ? "" : error.getMessage());
            steps.add(step);
            throw error;
        }

        List<Map<String, Object>> toolCalls = new ArrayList<>();
        List<Map<String, Object>> toolResults = new ArrayList<>();
        for (Message message : request.messages()) {
            for (ToolCall call : message.toolCalls()) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("name", call.name());
                item.put("arguments", call.arguments());
                toolCalls.add(item);
            }
            if (Message.TOOL.equals(message.role())) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("tool_id", message.toolId());
                item.put("content", truncate(message.content()));
                toolResults.add(item);
            }
        }

        List<Map<String, Object>> outputCalls = new ArrayList<>();
        for (ToolCall call : response.message().toolCalls()) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("name", call.name());
            item.put("arguments", call.arguments());
            outputCalls.add(item);
        }

        Map<String, Object> output = new LinkedHashMap<>();
        output.put("content", truncate(response.message().content()));
        output.put("tool_calls", outputCalls);

        Map<String, Object> step = new LinkedHashMap<>();
        step.put("tool_calls", toolCalls);
        step.put("tool_results", toolResults);
        step.put("model_output", output);
        steps.add(step);

        return response;
    }

    public List<Map<String, Object>> steps() {
        return steps;
    }

    private static String truncate(String text) {
        if (text == null) {
            return "";
        }
        return text.length() > 800 ? text.substring(0, 800) + "..." : text;
    }
}
