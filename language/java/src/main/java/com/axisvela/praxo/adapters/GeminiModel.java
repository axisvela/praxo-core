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
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.stream.Stream;

public final class GeminiModel implements StreamingModel {
    private final GeminiConfig config;
    private final HttpClient client;

    public GeminiModel(GeminiConfig config) {
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
                    "MODEL_CONFIG", "gemini: API key is required");
        }
        if (config.model() == null || config.model().isEmpty()) {
            throw new PraxoException(
                    "MODEL_CONFIG", "gemini: model is required");
        }
    }

    private HttpRequest httpRequest(Request request, boolean stream) {
        String model = URLEncoder.encode(
                config.model(), StandardCharsets.UTF_8);
        String suffix = stream
                ? ":streamGenerateContent?alt=sse" : ":generateContent";
        HttpRequest.Builder builder = HttpRequest.newBuilder(
                        URI.create(config.baseUrl()
                                + "/v1beta/models/" + model + suffix))
                .timeout(Duration.ofSeconds(config.timeoutSeconds()))
                .header("Content-Type", "application/json")
                .header("Accept", stream
                        ? "text/event-stream" : "application/json")
                .header("x-goog-api-key", config.apiKey())
                .POST(HttpRequest.BodyPublishers.ofString(
                        Json.stringify(payload(request))));
        for (Map.Entry<String, String> entry : config.headers().entrySet()) {
            builder.header(entry.getKey(), entry.getValue());
        }
        return builder.build();
    }

    private Map<String, Object> payload(Request request) {
        Object[] built = buildContents(request.messages());
        @SuppressWarnings("unchecked")
        Map<String, Object> system = (Map<String, Object>) built[0];
        @SuppressWarnings("unchecked")
        List<Object> contents = (List<Object>) built[1];
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("contents", contents);
        if (system != null) {
            payload.put("system_instruction", system);
        }
        if (!request.tools().isEmpty()) {
            List<Object> declarations = new ArrayList<>();
            for (ToolSpec spec : request.tools()) {
                Map<String, Object> declaration = new LinkedHashMap<>();
                declaration.put("name", spec.name());
                declaration.put("description", spec.description());
                declaration.put("parameters", spec.parameters() == null
                        ? Map.of("type", "object", "properties", Map.of())
                        : spec.parameters());
                declarations.add(declaration);
            }
            payload.put("tools", List.of(
                    Map.of("functionDeclarations", declarations)));
            payload.put("toolConfig", Map.of(
                    "functionCallingConfig",
                    Map.of("mode", toolMode(request.toolChoice()))));
        }
        if (request.temperature() != 0 || config.maxOutputTokens() > 0) {
            Map<String, Object> generation = new LinkedHashMap<>();
            generation.put("temperature", request.temperature());
            generation.put("maxOutputTokens", config.maxOutputTokens());
            payload.put("generationConfig", generation);
        }
        return payload;
    }

    private Object[] buildContents(List<Message> messages) {
        List<Object> systemParts = new ArrayList<>();
        List<Object> contents = new ArrayList<>();
        List<Object> toolParts = new ArrayList<>();
        Map<String, String> names = new LinkedHashMap<>();
        for (Message message : messages) {
            if (Message.SYSTEM.equals(message.role())) {
                if (message.content() != null && !message.content().isEmpty()) {
                    systemParts.add(Map.of("text", message.content()));
                }
                continue;
            }
            if (Message.TOOL.equals(message.role())) {
                String name = names.getOrDefault(
                        message.toolId() == null ? "" : message.toolId(),
                        message.toolId() == null ? "tool" : message.toolId());
                Map<String, Object> response = new LinkedHashMap<>();
                response.put("name", name);
                response.put("response",
                        Map.of("result", message.content() == null
                                ? "" : message.content()));
                Map<String, Object> part = new LinkedHashMap<>();
                part.put("functionResponse", response);
                toolParts.add(part);
                continue;
            }
            flushTools(contents, toolParts);
            List<Object> parts = messageParts(message);
            if (!parts.isEmpty()) {
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("role", Message.ASSISTANT.equals(message.role())
                        ? "model" : "user");
                item.put("parts", parts);
                contents.add(item);
            }
            for (ToolCall call : message.toolCalls()) {
                if (!call.id().isEmpty() && !call.name().isEmpty()) {
                    names.put(call.id(), call.name());
                }
            }
        }
        flushTools(contents, toolParts);
        Map<String, Object> system = systemParts.isEmpty()
                ? null : Map.of("parts", systemParts);
        return new Object[] {system, contents};
    }

    private static void flushTools(List<Object> contents, List<Object> parts) {
        if (parts.isEmpty()) {
            return;
        }
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("role", "user");
        item.put("parts", new ArrayList<>(parts));
        contents.add(item);
        parts.clear();
    }

    private static List<Object> messageParts(Message message) {
        List<Object> parts = new ArrayList<>();
        if (message.content() != null && !message.content().isEmpty()) {
            parts.add(Map.of("text", message.content()));
        }
        for (var block : message.contentBlocks()) {
            if ("text".equals(block.type())
                    && block.text() != null && !block.text().isEmpty()) {
                parts.add(Map.of("text", block.text()));
            }
        }
        for (ToolCall call : message.toolCalls()) {
            Map<String, Object> function = new LinkedHashMap<>();
            function.put("name", call.name());
            function.put("args", call.arguments());
            parts.add(Map.of("functionCall", function));
        }
        return parts;
    }

    private static String toolMode(String choice) {
        if ("required".equals(choice)) {
            return "ANY";
        }
        if ("none".equals(choice)) {
            return "NONE";
        }
        return "AUTO";
    }

    private static Response parseResponse(Map<String, Object> data) {
        if (data.get("error") != null) {
            throw new PraxoException(
                    "MODEL_HTTP", "gemini: " + Json.stringify(data.get("error")));
        }
        List<Object> candidates = Json.asArray(data.get("candidates"));
        if (candidates.isEmpty()) {
            throw new PraxoException("MODEL_HTTP", "gemini: empty response");
        }
        Map<String, Object> candidate = Json.asObject(candidates.get(0));
        Map<String, Object> content = Json.asObject(candidate.get("content"));
        Object[] parsed = parseParts(Json.asArray(content.get("parts")));
        Map<String, Object> usage = Json.asObject(data.get("usageMetadata"));
        return new Response(
                new Message(Message.ASSISTANT, (String) parsed[0],
                        List.of(), castCalls(parsed[1]), null),
                new Usage(
                        num(usage.get("promptTokenCount")),
                        num(usage.get("candidatesTokenCount")),
                        num(usage.get("cachedContentTokenCount"))),
                str(candidate.get("finishReason")));
    }

    @SuppressWarnings("unchecked")
    private static List<ToolCall> castCalls(Object value) {
        return (List<ToolCall>) value;
    }

    private Response parseStream(Stream<String> lines, Consumer<String> onDelta) {
        StringBuilder content = new StringBuilder();
        List<ToolCall> calls = new ArrayList<>();
        long inputTokens = 0;
        long outputTokens = 0;
        long cachedTokens = 0;
        String finishReason = null;
        try (lines) {
            for (String raw : (Iterable<String>) lines::iterator) {
                String line = raw.trim();
                if (!line.startsWith("data:")) {
                    continue;
                }
                String payload = line.substring(5).trim();
                if (payload.isEmpty() || "[DONE]".equals(payload)) {
                    continue;
                }
                Map<String, Object> chunk = Json.object(payload);
                if (chunk.get("error") != null) {
                    throw new PraxoException(
                            "MODEL_HTTP", "gemini: " + Json.stringify(
                                    chunk.get("error")));
                }
                Object rawUsage = chunk.get("usageMetadata");
                Map<String, Object> usage = rawUsage instanceof Map<?, ?>
                        ? Json.asObject(rawUsage)
                        : new LinkedHashMap<>();
                inputTokens = num(usage.get("promptTokenCount"));
                outputTokens = num(
                        usage.get("candidatesTokenCount"));
                cachedTokens = num(
                        usage.get("cachedContentTokenCount"));
                Object rawCandidates = chunk.get("candidates");
                List<Object> candidates = rawCandidates instanceof List<?>
                        ? Json.asArray(rawCandidates)
                        : List.of();
                if (candidates.isEmpty()) {
                    continue;
                }
                Map<String, Object> candidate =
                        Json.asObject(candidates.get(0));
                String reason = str(candidate.get("finishReason"));
                if (!reason.isEmpty()) {
                    finishReason = reason;
                }
                Map<String, Object> candidateContent =
                        Json.asObject(candidate.get("content"));
                for (Object rawPart : Json.asArray(
                        candidateContent.get("parts"))) {
                    Map<String, Object> part = Json.asObject(rawPart);
                    String text = str(part.get("text"));
                    if (!text.isEmpty()) {
                        content.append(text);
                        onDelta.accept(text);
                    }
                    if (part.get("functionCall") != null) {
                        Map<String, Object> call =
                                Json.asObject(part.get("functionCall"));
                        calls.add(new ToolCall(
                                "call-" + (calls.size() + 1),
                                str(call.get("name")),
                                Json.asObject(call.get("args"))));
                    }
                }
            }
        }
        return new Response(
                new Message(Message.ASSISTANT, content.toString(),
                        List.of(), calls, null),
                new Usage(inputTokens, outputTokens, cachedTokens),
                finishReason);
    }

    private static Object[] parseParts(List<Object> parts) {
        StringBuilder text = new StringBuilder();
        List<ToolCall> calls = new ArrayList<>();
        for (Object raw : parts) {
            Map<String, Object> part = Json.asObject(raw);
            text.append(str(part.get("text")));
            if (part.get("functionCall") != null) {
                Map<String, Object> call =
                        Json.asObject(part.get("functionCall"));
                calls.add(new ToolCall(
                        "call-" + (calls.size() + 1),
                        str(call.get("name")),
                        Json.asObject(call.get("args"))));
            }
        }
        return new Object[] {text.toString(), calls};
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
                    "gemini: HTTP " + status + ": "
                            + (body == null ? "" : body.substring(
                                    0, Math.min(body.length(), 512))));
        }
    }
}
