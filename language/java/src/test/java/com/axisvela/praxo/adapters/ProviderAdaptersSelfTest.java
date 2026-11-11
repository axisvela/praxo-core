package com.axisvela.praxo.adapters;

import com.sun.net.httpserver.HttpServer;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.util.Json;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class ProviderAdaptersSelfTest {
    private ProviderAdaptersSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(
                new InetSocketAddress("127.0.0.1", 0), 0);
        Map<String, String> headers = new LinkedHashMap<>();
        Map<String, Object> bodies = new LinkedHashMap<>();
        server.createContext("/v1/messages", exchange -> {
            capture(exchange, headers, bodies, "anthropic");
            boolean stream = Boolean.TRUE.equals(
                    Json.asObject(bodies.get("anthropic")).get("stream"));
            respond(exchange, stream, anthropicStream(), anthropicResponse());
        });
        server.createContext("/v1beta/", exchange -> {
            capture(exchange, headers, bodies, "gemini");
            respond(exchange, exchange.getRequestURI().getPath()
                    .contains(":streamGenerateContent"), geminiStream(),
                    geminiResponse());
        });
        server.start();
        try {
            int port = server.getAddress().getPort();
            Request request = new Request(
                    null,
                    List.of(
                            Message.of(Message.SYSTEM, "be brief"),
                            Message.of(Message.USER, "hi")),
                    List.of(new ToolSpec(
                            "echo", "Echo",
                            Map.of("type", "object"), null)),
                    "auto", null, null, 0.2);

            AnthropicModel anthropic = new AnthropicModel(
                    new AnthropicConfig(
                            "http://127.0.0.1:" + port, "ak",
                            "claude-test", "2023-06-01", 1024, 60, Map.of()));
            Response response = anthropic.generate(request);
            check("hello".equals(response.message().content()),
                    "anthropic content");
            check("tool-1".equals(
                    response.message().toolCalls().get(0).id()),
                    "anthropic call id");
            check("hi".equals(response.message().toolCalls().get(0)
                    .arguments().get("text")), "anthropic arguments");
            check(response.usage().cachedTokens() == 2, "anthropic usage");
            check("end_turn".equals(response.finishReason()),
                    "anthropic finish");
            check("ak".equals(headers.get("anthropic-x-api-key")),
                    "anthropic key");
            check("2023-06-01".equals(
                    headers.get("anthropic-anthropic-version")),
                    "anthropic version");
            Map<String, Object> body =
                    Json.asObject(bodies.get("anthropic"));
            check("be brief".equals(Json.string(body.get("system"))),
                    "anthropic system");
            check("auto".equals(Json.string(
                    Json.asObject(body.get("tool_choice")).get("type"))),
                    "anthropic tool choice");

            List<String> deltas = new ArrayList<>();
            Response streamed = anthropic.generateStream(
                    request, deltas::add);
            check(deltas.equals(List.of("he", "llo")),
                    "anthropic deltas");
            check("hi".equals(streamed.message().toolCalls().get(0)
                    .arguments().get("text")), "anthropic stream arguments");

            GeminiModel gemini = new GeminiModel(
                    new GeminiConfig(
                            "http://127.0.0.1:" + port, "gk",
                            "gemini-test", 0, 60, Map.of()));
            response = gemini.generate(request);
            check("hello".equals(response.message().content()),
                    "gemini content");
            check("echo".equals(
                    response.message().toolCalls().get(0).name()),
                    "gemini call name");
            check(response.usage().inputTokens() == 3, "gemini usage");
            check("STOP".equals(response.finishReason()), "gemini finish");
            check("gk".equals(headers.get("gemini-x-goog-api-key")),
                    "gemini key");
            body = Json.asObject(bodies.get("gemini"));
            Map<String, Object> system = Json.asObject(
                    body.get("system_instruction"));
            List<Object> parts = Json.asArray(system.get("parts"));
            check("be brief".equals(Json.string(
                    Json.asObject(parts.get(0)).get("text"))),
                    "gemini system");
            check("AUTO".equals(Json.string(Json.asObject(
                    Json.asObject(body.get("toolConfig"))
                            .get("functionCallingConfig")).get("mode"))),
                    "gemini tool mode");

            deltas.clear();
            streamed = gemini.generateStream(request, deltas::add);
            check(deltas.equals(List.of("he", "llo")), "gemini deltas");
            check("hi".equals(streamed.message().toolCalls().get(0)
                    .arguments().get("text")), "gemini stream arguments");
        } finally {
            server.stop(0);
        }
        System.out.println("provider adapters ok");
    }

    private static void capture(
            com.sun.net.httpserver.HttpExchange exchange,
            Map<String, String> headers,
            Map<String, Object> bodies,
            String prefix) throws java.io.IOException {
        for (Map.Entry<String, List<String>> entry
                : exchange.getRequestHeaders().entrySet()) {
            headers.put(prefix + "-" + entry.getKey().toLowerCase(),
                    entry.getValue().get(0));
        }
        bodies.put(prefix, Json.object(new String(
                exchange.getRequestBody().readAllBytes(),
                StandardCharsets.UTF_8)));
    }

    private static void respond(
            com.sun.net.httpserver.HttpExchange exchange,
            boolean stream,
            List<String> events,
            String body) throws java.io.IOException {
        exchange.getResponseHeaders().add("Content-Type",
                stream ? "text/event-stream" : "application/json");
        exchange.sendResponseHeaders(200, 0);
        try (OutputStream out = exchange.getResponseBody()) {
            if (stream) {
                for (String event : events) {
                    out.write(("data: " + event + "\n\n")
                            .getBytes(StandardCharsets.UTF_8));
                }
            } else {
                out.write(body.getBytes(StandardCharsets.UTF_8));
            }
        }
    }

    private static String anthropicResponse() {
        return """
                {"content":[{"type":"text","text":"hello"},{"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":4,"cache_read_input_tokens":2}}
                """;
    }

    private static List<String> anthropicStream() {
        return List.of(
                "{\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":3}}}",
                "{\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\"}}",
                "{\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"he\"}}",
                "{\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"llo\"}}",
                "{\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\",\"id\":\"tool-1\",\"name\":\"echo\",\"input\":{}}}",
                "{\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{\\\"text\\\":\"}}",
                "{\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"\\\"hi\\\"}\"}}",
                "{\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":4}}",
                "{\"type\":\"message_stop\"}");
    }

    private static String geminiResponse() {
        return """
                {"candidates":[{"content":{"parts":[{"text":"hello"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":4}}
                """;
    }

    private static List<String> geminiStream() {
        return List.of(
                "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"he\"}]}}]}",
                "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"llo\"}]}}]}",
                "{\"candidates\":[{\"content\":{\"parts\":[{\"functionCall\":{\"name\":\"echo\",\"args\":{\"text\":\"hi\"}}}]},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":3,\"candidatesTokenCount\":4}}");
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
