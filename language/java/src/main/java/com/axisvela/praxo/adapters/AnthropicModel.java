package com.axisvela.praxo.adapters;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.StreamingModel;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.model.Usage;
import com.axisvela.praxo.util.Json;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.stream.Stream;

public final class AnthropicModel implements StreamingModel {
    private final AnthropicConfig config;
    private final HttpClient client;

    public AnthropicModel(AnthropicConfig config) {
        this.config = config;
        this.client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(config.timeoutSeconds()))
                .version(HttpClient.Version.HTTP_1_1)
                .build();
    }

    @Override
    public Response generate(Request request) throws Exception {
        validate();
        HttpResponse<String> response = client.send(
                httpRequest(request, false),
                HttpResponse.BodyHandlers.ofString());
        checkStatus(response.statusCode(), response.body());
        return parseResponse(Json.object(response.body()));
    }

    @Override
    public Response generateStream(Request request, Consumer<String> onDelta)
            throws Exception {
        validate();
        HttpResponse<Stream<String>> response = client.send(
                httpRequest(request, true),
                HttpResponse.BodyHandlers.ofLines());
        checkStatus(response.statusCode(), "");
        return parseStream(response.body(), onDelta);
    }

    private void validate() {
        if (config.apiKey() == null || config.apiKey().isEmpty()) {
            throw new PraxoException(
                    "MODEL_CONFIG", "anthropic: API key is required");
        }
        if (config.model() == null || config.model().isEmpty()) {
            throw new PraxoException(
                    "MODEL_CONFIG", "anthropic: model is required");
        }
    }

    private HttpRequest httpRequest(Request request, boolean stream) {
        HttpRequest.Builder builder = HttpRequest.newBuilder(
                        URI.create(config.baseUrl() + "/v1/messages"))
                .timeout(Duration.ofSeconds(config.timeoutSeconds()))
                .header("Content-Type", "application/json")
                .header("Accept", stream ? "text/event-stream" : "application/json")
                .header("x-api-key", config.apiKey())
                .header("anthropic-version", config.version())
                .POST(HttpRequest.BodyPublishers.ofString(
                        Json.stringify(payload(request, stream))));
        for (Map.Entry<String, String> entry : config.headers().entrySet()) {
            builder.header(entry.getKey(), entry.getValue());
        }
        return builder.build();
    }

    private Map<String, Object> payload(Request request, boolean stream) {
        Object[] built = buildMessages(request.messages());
        @SuppressWarnings("unchecked")
        String system = (String) built[0];
        @SuppressWarnings("unchecked")
        List<Object> messages = (List<Object>) built[1];
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("model", request.model() == null
                ? config.model() : request.model());
        payload.put("max_tokens", config.maxTokens());
        payload.put("messages", messages);
        payload.put("stream", stream);
        if (!system.isEmpty()) {
            payload.put("system", system);
        }
        if (!request.tools().isEmpty()) {
            List<Object> tools = new ArrayList<>();
            for (ToolSpec spec : request.tools()) {
                Map<String, Object> tool = new LinkedHashMap<>();
                tool.put("name", spec.name());
                tool.put("description", spec.description());
                tool.put("input_schema", spec.parameters() == null
                        ? Map.of("type", "object", "properties", Map.of())
                        : spec.parameters());
                tools.add(tool);
            }
            payload.put("tools", tools);
            Map<String, Object> choice = toolChoice(request.toolChoice());
            if (choice != null) {
                payload.put("tool_choice", choice);
            }
        }
        if (request.temperature() != 0) {
            payload.put("temperature", request.temperature());
        }
        return payload;
    }

    private Object[] buildMessages(List<Message> messages) {
        List<String> system = new ArrayList<>();
        List<Object> out = new ArrayList<>();
        List<Object> toolResults = new ArrayList<>();
        for (Message message : messages) {
            if (Message.SYSTEM.equals(message.role())) {
                if (message.content() != null && !message.content().isEmpty()) {
                    system.add(message.content());
                }
                continue;
            }
            if (Message.TOOL.equals(message.role())) {
                Map<String, Object> result = new LinkedHashMap<>();
                result.put("type", "tool_result");
                result.put("tool_use_id",
                        message.toolId() == null ? "" : message.toolId());
                result.put("content",
                        message.content() == null ? "" : message.content());
                toolResults.add(result);
                continue;
            }
            flushTools(out, toolResults);
            List<Object> content = messageContent(message);
            if (!content.isEmpty()) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("role", message.role());
                item.put("content", content);
                out.add(item);
            }
        }
        flushTools(out, toolResults);
        return new Object[] {String.join("\n\n", system), out};
    }

    private static void flushTools(List<Object> out, List<Object> results) {
        if (results.isEmpty()) {
            return;
        }
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("role", "user");
        item.put("content", new ArrayList<>(results));
        out.add(item);
        results.clear();
    }

    private static List<Object> messageContent(Message message) {
        List<Object> content = new ArrayList<>();
        if (message.content() != null && !message.content().isEmpty()) {
            content.add(Map.of("type", "text", "text", message.content()));
        }
        for (var block : message.contentBlocks()) {
            if ("text".equals(block.type())
                    && block.text() != null && !block.text().isEmpty()) {
                content.add(Map.of("type", "text", "text", block.text()));
            }
        }
        for (ToolCall call : message.toolCalls()) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("type", "tool_use");
            item.put("id", call.id());
            item.put("name", call.name());
            item.put("input", call.arguments());
            content.add(item);
        }
        return content;
    }

    private static Map<String, Object> toolChoice(String choice) {
        if (choice == null) {
            return null;
        }
        return switch (choice) {
            case "auto" -> Map.of("type", "auto");
            case "required" -> Map.of("type", "any");
            case "none" -> Map.of("type", "none");
            default -> null;
        };
    }

    private static Response parseResponse(Map<String, Object> data) {
        if (data.get("error") != null) {
            Map<String, Object> error = Json.asObject(data.get("error"));
            throw new PraxoException(
                    "MODEL_HTTP", "anthropic: " + str(error.get("message")));
        }
        StringBuilder text = new StringBuilder();
        List<ToolCall> calls = new ArrayList<>();
        for (Object raw : Json.asArray(data.get("content"))) {
            Map<String, Object> block = Json.asObject(raw);
            if ("text".equals(str(block.get("type")))) {
                text.append(str(block.get("text")));
            } else if ("tool_use".equals(str(block.get("type")))) {
                calls.add(new ToolCall(
                        str(block.get("id")),
                        str(block.get("name")),
                        Json.asObject(block.get("input"))));
            }
        }
        Map<String, Object> usage = Json.asObject(data.get("usage"));
        return new Response(
                new Message(Message.ASSISTANT, text.toString(),
                        List.of(), calls, null),
                new Usage(
                        num(usage.get("input_tokens")),
                        num(usage.get("output_tokens")),
                        num(usage.get("cache_read_input_tokens"))),
                str(data.get("stop_reason")));
    }

    private Response parseStream(Stream<String> lines, Consumer<String> onDelta) {
        StringBuilder content = new StringBuilder();
        Map<Integer, BlockState> blocks = new LinkedHashMap<>();
        long inputTokens = 0;
        long outputTokens = 0;
        long cachedTokens = 0;
        String stopReason = null;
        boolean stopped = false;
        try (lines) {
            for (String raw : (Iterable<String>) lines::iterator) {
                String line = raw.trim();
                if (!line.startsWith("data:")) {
                    continue;
                }
                String payload = line.substring(5).trim();
                if (payload.isEmpty()) {
                    continue;
                }
                Map<String, Object> event = Json.object(payload);
                String type = str(event.get("type"));
                if ("message_start".equals(type)) {
                    Map<String, Object> message =
                            Json.asObject(event.get("message"));
                    Map<String, Object> usage =
                            Json.asObject(message.get("usage"));
                    inputTokens = num(usage.get("input_tokens"));
                    cachedTokens = num(
                            usage.get("cache_read_input_tokens"));
                } else if ("content_block_start".equals(type)) {
                    int index = Json.intValue(event.get("index"));
                    Map<String, Object> block =
                            Json.asObject(event.get("content_block"));
                    BlockState state = new BlockState();
                    state.kind = str(block.get("type"));
                    state.id = str(block.get("id"));
                    state.name = str(block.get("name"));
                    state.input = Json.asObject(block.get("input"));
                    blocks.put(index, state);
                    String text = str(block.get("text"));
                    if (!text.isEmpty()) {
                        content.append(text);
                        onDelta.accept(text);
                    }
                } else if ("content_block_delta".equals(type)) {
                    int index = Json.intValue(event.get("index"));
                    BlockState block = blocks.computeIfAbsent(
                            index, ignored -> new BlockState());
                    Map<String, Object> delta =
                            Json.asObject(event.get("delta"));
                    String deltaType = str(delta.get("type"));
                    if ("text_delta".equals(deltaType)) {
                        String text = str(delta.get("text"));
                        if (!text.isEmpty()) {
                            content.append(text);
                            onDelta.accept(text);
                        }
                    } else if ("input_json_delta".equals(deltaType)) {
                        block.arguments.append(
                                str(delta.get("partial_json")));
                    }
                } else if ("message_delta".equals(type)) {
                    Map<String, Object> delta =
                            Json.asObject(event.get("delta"));
                    if (!str(delta.get("stop_reason")).isEmpty()) {
                        stopReason = str(delta.get("stop_reason"));
                    }
                    Map<String, Object> usage =
                            Json.asObject(event.get("usage"));
                    outputTokens = num(usage.get("output_tokens"));
                    long input = num(usage.get("input_tokens"));
                    if (input != 0) {
                        inputTokens = input;
                    }
                } else if ("message_stop".equals(type)) {
                    stopped = true;
                    break;
                } else if ("error".equals(type)) {
                    throw new PraxoException(
                            "MODEL_HTTP", "anthropic: " + Json.stringify(
                                    event.get("error")));
                }
            }
        }
        if (!stopped) {
            throw new PraxoException(
                    "MODEL_STREAM",
                    "anthropic: stream ended before completion");
        }
        List<ToolCall> calls = new ArrayList<>();
        for (BlockState block : blocks.values()) {
            if (!"tool_use".equals(block.kind)) {
                continue;
            }
            Map<String, Object> arguments = block.input;
            if (block.arguments.length() > 0) {
                arguments = Json.object(block.arguments.toString());
            }
            calls.add(new ToolCall(
                    block.id.isEmpty()
                            ? "call-" + (calls.size() + 1) : block.id,
                    block.name,
                    arguments));
        }
        return new Response(
                new Message(Message.ASSISTANT, content.toString(),
                        List.of(), calls, null),
                new Usage(inputTokens, outputTokens, cachedTokens),
                stopReason);
    }

    private static long num(Object value) {
        return value == null ? 0 : Json.integer(value);
    }

    private static String str(Object value) {
        String text = Json.string(value);
        return text == null ? "" : text;
    }

    private static void checkStatus(int status, String body) {
        if (status < 200 || status >= 300) {
            throw new PraxoException(
                    "MODEL_HTTP",
                    "anthropic: HTTP " + status + ": "
                            + (body == null ? "" : body.substring(
                                    0, Math.min(body.length(), 512))));
        }
    }

    private static final class BlockState {
        private String kind = "";
        private String id = "";
        private String name = "";
        private Map<String, Object> input = new LinkedHashMap<>();
        private final StringBuilder arguments = new StringBuilder();
    }
}
