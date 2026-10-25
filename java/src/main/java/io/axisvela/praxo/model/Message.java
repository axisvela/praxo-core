package io.axisvela.praxo.model;

import io.axisvela.praxo.util.Json;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public record Message(
        String role,
        String content,
        List<ContentBlock> contentBlocks,
        List<ToolCall> toolCalls,
        String toolId) {

    public static final String SYSTEM = "system";
    public static final String USER = "user";
    public static final String ASSISTANT = "assistant";
    public static final String TOOL = "tool";

    public Message {
        contentBlocks = contentBlocks == null ? List.of() : List.copyOf(contentBlocks);
        toolCalls = toolCalls == null ? List.of() : List.copyOf(toolCalls);
    }

    public static Message of(String role, String content) {
        return new Message(role, content, List.of(), List.of(), null);
    }

    public static Message assistant(String content, List<ToolCall> calls) {
        return new Message(ASSISTANT, content, List.of(), calls, null);
    }

    public static Message tool(String content, String toolId) {
        return new Message(TOOL, content, List.of(), List.of(), toolId);
    }

    public static Message fromWire(Object raw) {
        Map<String, Object> map = Json.asObject(raw);
        List<ContentBlock> blocks = new ArrayList<>();
        if (map.get("contentBlocks") != null) {
            for (Object item : Json.asArray(map.get("contentBlocks"))) {
                Map<String, Object> block = Json.asObject(item);
                blocks.add(new ContentBlock(
                        Json.string(block.get("type")),
                        Json.string(block.get("text")),
                        Json.string(block.get("image_url")),
                        Json.string(block.get("data"))));
            }
        }
        return new Message(
                Json.string(map.get("role")),
                Json.string(map.get("content")),
                blocks,
                ToolCall.listFromWire(map.get("toolCalls")),
                Json.string(map.get("toolId")));
    }

    public Map<String, Object> toWire() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("role", role);
        if (content != null && !content.isEmpty()) {
            out.put("content", content);
        }
        if (!contentBlocks.isEmpty()) {
            List<Object> blocks = new ArrayList<>();
            for (ContentBlock block : contentBlocks) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("type", block.type());
                if (block.text() != null) {
                    item.put("text", block.text());
                }
                if (block.imageUrl() != null) {
                    item.put("image_url", block.imageUrl());
                }
                if (block.data() != null) {
                    item.put("data", block.data());
                }
                blocks.add(item);
            }
            out.put("contentBlocks", blocks);
        }
        if (!toolCalls.isEmpty()) {
            List<Object> calls = new ArrayList<>();
            for (ToolCall call : toolCalls) {
                calls.add(call.toWire());
            }
            out.put("toolCalls", calls);
        }
        if (toolId != null) {
            out.put("toolId", toolId);
        }
        return out;
    }
}
