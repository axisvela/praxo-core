package com.axisvela.praxo.adapters;

import com.axisvela.praxo.util.Json;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class FakeMcpServer {
    private FakeMcpServer() {
    }

    public static void main(String[] args) throws Exception {
        String mode = args.length > 0 ? args[0] : "default";
        Path marker = args.length > 1 ? Path.of(args[1]) : null;
        boolean initialized = false;
        BufferedReader reader = new BufferedReader(new InputStreamReader(
                System.in, StandardCharsets.UTF_8));
        BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(
                System.out, StandardCharsets.UTF_8));
        String line;
        while ((line = reader.readLine()) != null) {
            if (line.isBlank()) {
                continue;
            }
            Map<String, Object> message;
            try {
                message = Json.object(line);
            } catch (RuntimeException error) {
                continue;
            }
            String method = message.get("method") instanceof String text
                    ? text : "";
            Object id = message.get("id");
            switch (method) {
                case "initialize" -> respond(writer, id, Map.of(
                        "protocolVersion", "2024-11-05",
                        "capabilities", Map.of("tools", Map.of()),
                        "serverInfo", Map.of(
                                "name", "fake-mcp", "version", "1.0.0")));
                case "notifications/initialized" -> initialized = true;
                case "notifications/cancelled" -> {
                    if (marker != null) {
                        Files.writeString(marker, "cancelled\n",
                                StandardCharsets.UTF_8,
                                StandardOpenOption.CREATE,
                                StandardOpenOption.APPEND);
                    }
                }
                case "tools/list" -> {
                    if (!initialized) {
                        error(writer, id, -32002, "not initialized");
                        continue;
                    }
                    Map<String, Object> params = asMap(message.get("params"));
                    respond(writer, id, listTools(mode, params));
                }
                case "tools/call" -> {
                    if (!initialized) {
                        error(writer, id, -32002, "not initialized");
                        continue;
                    }
                    Map<String, Object> params = asMap(message.get("params"));
                    String name = params.get("name") instanceof String text
                            ? text : "";
                    if ("hang".equals(mode) && "hang".equals(name)) {
                        continue;
                    }
                    respond(writer, id, callTool(params));
                }
                default -> {
                    if (id != null) {
                        error(writer, id, -32601, "method not found");
                    }
                }
            }
        }
    }

    private static Map<String, Object> listTools(
            String mode,
            Map<String, Object> params) {
        String cursor = params.get("cursor") instanceof String text ? text : "";
        if ("repeated-cursor".equals(mode)) {
            String label = cursor.isEmpty() ? "start" : cursor;
            return page(List.of(genericTool("loop-" + label)), "loop");
        }
        if ("duplicate-name".equals(mode)) {
            if (cursor.isEmpty()) {
                return page(List.of(genericTool("dup")), "page-2");
            }
            return page(List.of(genericTool("dup")), null);
        }
        if ("hang".equals(mode)) {
            return page(List.of(tool("hang", "Never responds",
                    schema(Map.of()))), null);
        }
        if (cursor.isEmpty()) {
            Map<String, Object> text = new LinkedHashMap<>();
            text.put("type", "string");
            Map<String, Object> properties = new LinkedHashMap<>();
            properties.put("text", text);
            Map<String, Object> schema = new LinkedHashMap<>();
            schema.put("type", "object");
            schema.put("properties", properties);
            schema.put("required", List.of("text"));
            Map<String, Object> a = new LinkedHashMap<>();
            a.put("type", "integer");
            Map<String, Object> b = new LinkedHashMap<>();
            b.put("type", "integer");
            Map<String, Object> addProperties = new LinkedHashMap<>();
            addProperties.put("a", a);
            addProperties.put("b", b);
            Map<String, Object> addSchema = new LinkedHashMap<>();
            addSchema.put("type", "object");
            addSchema.put("properties", addProperties);
            addSchema.put("required", List.of("a", "b"));
            return page(List.of(
                    tool("echo", "Echo input", schema),
                    tool("add", "Add two integers", addSchema)), "page-2");
        }
        if ("page-2".equals(cursor)) {
            return page(List.of(
                    tool("fail", "Always fails", schema(Map.of())),
                    tool("multi", "Return two text blocks",
                            schema(Map.of()))), null);
        }
        return page(List.of(), null);
    }

    private static Map<String, Object> callTool(Map<String, Object> params) {
        String name = params.get("name") instanceof String text ? text : "";
        Map<String, Object> arguments = asMap(params.get("arguments"));
        Map<String, Object> result = new LinkedHashMap<>();
        switch (name) {
            case "echo" -> {
                Object text = arguments.get("text");
                result.put("content", List.of(textBlock(
                        text instanceof String value ? value : "")));
                result.put("isError", false);
            }
            case "add" -> {
                long a = arguments.get("a") instanceof Number aValue
                        ? aValue.longValue() : 0;
                long b = arguments.get("b") instanceof Number bValue
                        ? bValue.longValue() : 0;
                result.put("content", List.of(textBlock(
                        Long.toString(a + b))));
                result.put("structuredContent", Map.of("sum", a + b));
                result.put("isError", false);
            }
            case "multi" -> {
                result.put("content", List.of(
                        textBlock("one"), textBlock("two")));
                result.put("isError", false);
            }
            case "fail" -> {
                result.put("content", List.of(textBlock("boom")));
                result.put("isError", true);
            }
            default -> {
                result.put("content", List.of(textBlock(
                        "unknown tool " + name)));
                result.put("isError", true);
            }
        }
        return result;
    }

    private static Map<String, Object> page(
            List<Object> tools,
            String nextCursor) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("tools", tools);
        if (nextCursor != null) {
            result.put("nextCursor", nextCursor);
        }
        return result;
    }

    private static Map<String, Object> tool(
            String name,
            String description,
            Map<String, Object> inputSchema) {
        Map<String, Object> tool = new LinkedHashMap<>();
        tool.put("name", name);
        tool.put("description", description);
        tool.put("inputSchema", inputSchema);
        return tool;
    }

    private static Map<String, Object> genericTool(String name) {
        return tool(name, "generic", schema(Map.of()));
    }

    private static Map<String, Object> schema(
            Map<String, Object> properties) {
        Map<String, Object> schema = new LinkedHashMap<>();
        schema.put("type", "object");
        schema.put("properties", properties);
        return schema;
    }

    private static Map<String, Object> textBlock(String text) {
        Map<String, Object> block = new LinkedHashMap<>();
        block.put("type", "text");
        block.put("text", text);
        return block;
    }

    private static Map<String, Object> asMap(Object raw) {
        if (raw instanceof Map<?, ?> value) {
            Map<String, Object> out = new LinkedHashMap<>();
            for (Map.Entry<?, ?> entry : value.entrySet()) {
                out.put(String.valueOf(entry.getKey()), entry.getValue());
            }
            return out;
        }
        return new LinkedHashMap<>();
    }

    private static void respond(
            BufferedWriter writer,
            Object id,
            Map<String, Object> result) throws Exception {
        Map<String, Object> message = new LinkedHashMap<>();
        message.put("jsonrpc", "2.0");
        message.put("id", id);
        message.put("result", result);
        write(writer, message);
    }

    private static void error(
            BufferedWriter writer,
            Object id,
            int code,
            String message) throws Exception {
        Map<String, Object> error = new LinkedHashMap<>();
        error.put("code", code);
        error.put("message", message);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("jsonrpc", "2.0");
        body.put("id", id);
        body.put("error", error);
        write(writer, body);
    }

    private static void write(
            BufferedWriter writer,
            Map<String, Object> message) throws Exception {
        writer.write(Json.stringify(message));
        writer.write('\n');
        writer.flush();
    }
}
