package com.axisvela.praxo.adapters;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ResponseFormat;
import com.axisvela.praxo.model.StreamingModel;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.model.Usage;
import com.axisvela.praxo.toolcall.ToolCalls;
import com.axisvela.praxo.util.Json;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.stream.Stream;

public final class OpenAICompatibleModel implements StreamingModel {
    private final OpenAIConfig config;
    private final HttpClient client;

    public OpenAICompatibleModel(OpenAIConfig config) {
        this.config = config;
        this.client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(config.timeoutSeconds()))
                .version(HttpClient.Version.HTTP_1_1)
                .build();
    }

    @Override
    public Response generate(Request request) throws Exception {
        HttpResponse<String> response = client.send(
                httpRequest(request, false),
                HttpResponse.BodyHandlers.ofString());
        checkStatus(response.statusCode(), response.body());
        return parseResponse(Json.object(response.body()));
    }

    @Override
    public Response generateStream(Request request, Consumer<String> onDelta)
            throws Exception {
        HttpResponse<Stream<String>> response = client.send(
                httpRequest(request, true),
                HttpResponse.BodyHandlers.ofLines());
        checkStatus(response.statusCode(), "");
        return parseStream(response.body(), onDelta);
    }

    private HttpRequest httpRequest(Request request, boolean stream) {
        String body = Json.stringify(payload(request, stream));
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(endpoint()))
                .timeout(Duration.ofSeconds(config.timeoutSeconds()))
                .header("Content-Type", "application/json")
                .header("Accept", stream ? "text/event-stream" : "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body));
        if (config.apiKey() != null && !config.apiKey().isEmpty()) {
            builder.header("Authorization", "Bearer " + config.apiKey());
        }
        for (Map.Entry<String, String> entry : config.headers().entrySet()) {
            builder.header(entry.getKey(), entry.getValue());
        }
        return builder.build();
    }

    private Map<String, Object> payload(Request request, boolean stream) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("model", request.model() == null
                ? config.model() : request.model());
        List<Object> messages = new ArrayList<>();
        for (Message message : request.messages()) {
            Map<String, Object> wire = message.toWire();
            if (!wire.containsKey("content") && !wire.containsKey("toolCalls")) {
                wire.put("content", "");
            }
            messages.add(wire);
        }
        payload.put("messages", messages);
        payload.put("stream", stream);
        if (!request.tools().isEmpty()) {
            List<Object> tools = new ArrayList<>();
            for (com.axisvela.praxo.model.ToolSpec spec : request.tools()) {
                Map<String, Object> function = new LinkedHashMap<>();
                function.put("name", spec.name());
                function.put("description", spec.description());
                if (spec.parameters() != null) {
                    function.put("parameters", spec.parameters());
                }
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("type", "function");
                item.put("function", function);
                tools.add(item);
            }
            payload.put("tools", tools);
        }
        if (request.toolChoice() != null) {
            payload.put("tool_choice", request.toolChoice());
        }
        if (request.responseFormat() != null) {
            ResponseFormat format = request.responseFormat();
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("name", format.name() == null || format.name().isEmpty()
                    ? "output" : format.name());
            body.put("schema", format.schema() == null ? Map.of() : format.schema());
            Map<String, Object> responseFormat = new LinkedHashMap<>();
            responseFormat.put("type", "json_schema");
            responseFormat.put("json_schema", body);
            payload.put("response_format", responseFormat);
        }
        if (request.temperature() != 0) {
            payload.put("temperature", request.temperature());
        }
        return payload;
    }

    private Response parseResponse(Map<String, Object> data) {
        List<Object> choices = Json.asArray(data.get("choices"));
        if (choices.isEmpty()) {
            throw new PraxoException(
                    "OPENAI_COMPAT_ERROR", "openaicompat: response has no choices");
        }
        Map<String, Object> choice = Json.asObject(choices.get(0));
        Map<String, Object> message = Json.asObject(choice.get("message"));
        List<ToolCall> calls = new ArrayList<>();
        if (message.get("tool_calls") != null) {
            List<Object> rawCalls = Json.asArray(message.get("tool_calls"));
            for (int index = 0; index < rawCalls.size(); index++) {
                calls.add(buildCall(index, Json.asObject(rawCalls.get(index))));
            }
        }
        return new Response(
                new Message(Message.ASSISTANT,
                        message.get("content") == null
                                ? "" : String.valueOf(message.get("content")),
                        List.of(), calls, null),
                parseUsage(data.get("usage")),
                choice.get("finish_reason") == null
                        ? null : String.valueOf(choice.get("finish_reason")));
    }

    private Response parseStream(Stream<String> lines, Consumer<String> onDelta) {
        StringBuilder content = new StringBuilder();
        Map<Integer, String[]> calls = new LinkedHashMap<>();
        Usage usage = Usage.zero();
        String finishReason = null;
        boolean done = false;
        try (lines) {
        for (String line : (Iterable<String>) lines::iterator) {
            String trimmed = line.trim();
            if (!trimmed.startsWith("data:")) {
                continue;
            }
            String chunk = trimmed.substring(5).trim();
            if (chunk.isEmpty()) {
                continue;
            }
            if (chunk.equals("[DONE]")) {
                done = true;
                break;
            }
            Map<String, Object> event = Json.object(chunk);
            if (event.get("usage") != null) {
                usage = parseUsage(event.get("usage"));
            }
            if (event.get("choices") == null) {
                continue;
            }
            for (Object item : Json.asArray(event.get("choices"))) {
                Map<String, Object> choice = Json.asObject(item);
                if (choice.get("finish_reason") != null) {
                    finishReason = String.valueOf(choice.get("finish_reason"));
                }
                Map<String, Object> delta =
                        choice.get("delta") == null
                                ? Map.of() : Json.asObject(choice.get("delta"));
                if (delta.get("content") instanceof String text && !text.isEmpty()) {
                    content.append(text);
                    onDelta.accept(text);
                }
                if (delta.get("tool_calls") != null) {
                    for (Object raw : Json.asArray(delta.get("tool_calls"))) {
                        Map<String, Object> call = Json.asObject(raw);
                        int index = call.get("index") == null
                                ? 0 : Json.intValue(call.get("index"));
                        String[] slot = calls.computeIfAbsent(
                                index, key -> new String[]{"", "", ""});
                        if (call.get("id") != null) {
                            slot[0] = String.valueOf(call.get("id"));
                        }
                        Map<String, Object> function =
                                call.get("function") == null
                                        ? Map.of() : Json.asObject(call.get("function"));
                        if (function.get("name") != null) {
                            slot[1] = slot[1] + function.get("name");
                        }
                        if (function.get("arguments") != null) {
                            slot[2] = slot[2] + function.get("arguments");
                        }
                    }
                }
            }
        }
        }
        if (!done && finishReason == null) {
            throw new PraxoException(
                    "OPENAI_COMPAT_ERROR",
                    "openaicompat: stream ended before completion");
        }
        List<ToolCall> toolCalls = new ArrayList<>();
        for (Map.Entry<Integer, String[]> entry : calls.entrySet()) {
            String[] slot = entry.getValue();
            Map<String, Object> raw = new LinkedHashMap<>();
            raw.put("id", slot[0].isEmpty()
                    ? "call-" + entry.getKey() : slot[0]);
            raw.put("name", slot[1]);
            raw.put("arguments", slot[2]);
            toolCalls.add(buildCall(entry.getKey(), raw));
        }
        return new Response(
                new Message(Message.ASSISTANT, content.toString(), List.of(),
                        toolCalls, null),
                usage,
                finishReason);
    }

    private static ToolCall buildCall(int index, Map<String, Object> raw) {
        Map<String, Object> function = raw.get("function") instanceof Map<?, ?>
                ? Json.asObject(raw.get("function"))
                : raw;
        String arguments = function.get("arguments") == null
                ? "{}" : String.valueOf(function.get("arguments"));
        Map<String, Object> input = ToolCalls.parseInputJson(arguments);
        if (input == null) {
            input = new LinkedHashMap<>();
            input.put("content", arguments);
        }
        return new ToolCall(
                raw.get("id") == null ? "call-" + index : String.valueOf(raw.get("id")),
                function.get("name") == null ? "" : String.valueOf(function.get("name")),
                input);
    }

    private static Usage parseUsage(Object raw) {
        if (raw == null) {
            return Usage.zero();
        }
        Map<String, Object> usage = Json.asObject(raw);
        long input = usage.get("prompt_tokens") == null
                ? 0 : Json.integer(usage.get("prompt_tokens"));
        long output = usage.get("completion_tokens") == null
                ? 0 : Json.integer(usage.get("completion_tokens"));
        long cached = 0;
        if (usage.get("prompt_tokens_details") instanceof Map<?, ?> details) {
            Map<String, Object> value = Json.asObject(details);
            cached = value.get("cached_tokens") == null
                    ? 0 : Json.integer(value.get("cached_tokens"));
        }
        return new Usage(input, output, cached);
    }

    private static void checkStatus(int status, String body) {
        if (status < 200 || status >= 300) {
            throw new PraxoException(
                    "OPENAI_COMPAT_HTTP",
                    "openaicompat: HTTP " + status + ": "
                            + (body == null ? "" : body.substring(0, Math.min(512, body.length()))));
        }
    }

    private String endpoint() {
        return config.baseUrl().replaceAll("/+$", "") + "/chat/completions";
    }
}
