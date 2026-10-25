package io.axisvela.praxo.adapters;

import com.sun.net.httpserver.HttpServer;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;
import io.axisvela.praxo.util.Json;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class OpenAICompatibleSelfTest {
    private OpenAICompatibleSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(
                new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            Map<String, Object> payload = Json.object(new String(
                    exchange.getRequestBody().readAllBytes(),
                    StandardCharsets.UTF_8));
            boolean stream = Boolean.TRUE.equals(payload.get("stream"));
            exchange.getResponseHeaders().add("Content-Type",
                    stream ? "text/event-stream" : "application/json");
            if (stream) {
                exchange.sendResponseHeaders(200, 0);
                try (OutputStream out = exchange.getResponseBody()) {
                    for (Map<String, Object> chunk : streamChunks()) {
                        out.write(("data: " + Json.stringify(chunk) + "\n\n")
                                .getBytes(StandardCharsets.UTF_8));
                    }
                    out.write("data: [DONE]\n\n"
                            .getBytes(StandardCharsets.UTF_8));
                }
                return;
            }
            byte[] body = Json.stringify(nonStreamResponse())
                    .getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(body);
            }
        });
        server.start();
        try {
            int port = server.getAddress().getPort();
            OpenAICompatibleModel model = new OpenAICompatibleModel(
                    OpenAIConfig.of("http://127.0.0.1:" + port + "/v1", "test"));
            Response response = model.generate(Request.of(List.of(
                    Message.of(Message.USER, "hi"))));
            check(response.message().content().equals("hello"), "content");
            check(response.message().toolCalls().size() == 1, "tool calls");
            check(response.message().toolCalls().get(0).name().equals("echo"),
                    "tool name");
            check(response.message().toolCalls().get(0).arguments()
                    .get("text").equals("hi"), "tool arguments");
            check(response.usage().inputTokens() == 3, "input usage");
            check(response.usage().outputTokens() == 4, "output usage");

            List<String> deltas = new ArrayList<>();
            Response streamed = model.generateStream(
                    Request.of(List.of(Message.of(Message.USER, "hi"))),
                    deltas::add);
            check(deltas.equals(List.of("he", "llo")), "deltas");
            check(streamed.message().content().equals("hello"),
                    "stream content");
            check(streamed.message().toolCalls().get(0).arguments()
                    .get("text").equals("hi"), "stream tool arguments");
        } finally {
            server.stop(0);
        }
        System.out.println("openai adapter ok");
    }

    private static Map<String, Object> nonStreamResponse() {
        Map<String, Object> message = new LinkedHashMap<>();
        message.put("role", "assistant");
        message.put("content", "hello");
        Map<String, Object> function = new LinkedHashMap<>();
        function.put("name", "echo");
        function.put("arguments", "{\"text\":\"hi\"}");
        Map<String, Object> call = new LinkedHashMap<>();
        call.put("id", "c1");
        call.put("function", function);
        message.put("tool_calls", List.of(call));
        Map<String, Object> choice = new LinkedHashMap<>();
        choice.put("message", message);
        choice.put("finish_reason", "stop");
        Map<String, Object> usage = new LinkedHashMap<>();
        usage.put("prompt_tokens", 3);
        usage.put("completion_tokens", 4);
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("choices", List.of(choice));
        response.put("usage", usage);
        return response;
    }

    private static List<Map<String, Object>> streamChunks() {
        List<Map<String, Object>> chunks = new ArrayList<>();
        chunks.add(chunk(Map.of("content", "he")));
        chunks.add(chunk(Map.of("content", "llo")));
        Map<String, Object> callStart = new LinkedHashMap<>();
        callStart.put("index", 0);
        callStart.put("id", "c1");
        callStart.put("function", Map.of(
                "name", "echo", "arguments", "{\"text\":"));
        Map<String, Object> delta = new LinkedHashMap<>();
        delta.put("tool_calls", List.of(callStart));
        chunks.add(chunk(delta));
        Map<String, Object> callEnd = new LinkedHashMap<>();
        callEnd.put("index", 0);
        callEnd.put("function", Map.of("arguments", "\"hi\"}"));
        Map<String, Object> deltaEnd = new LinkedHashMap<>();
        deltaEnd.put("tool_calls", List.of(callEnd));
        chunks.add(chunk(deltaEnd));
        Map<String, Object> usage = new LinkedHashMap<>();
        usage.put("prompt_tokens", 3);
        usage.put("completion_tokens", 4);
        Map<String, Object> finalChunk = new LinkedHashMap<>();
        finalChunk.put("choices", List.of());
        finalChunk.put("usage", usage);
        chunks.add(finalChunk);
        return chunks;
    }

    private static Map<String, Object> chunk(Map<String, Object> delta) {
        Map<String, Object> choice = new LinkedHashMap<>();
        choice.put("delta", delta);
        Map<String, Object> chunk = new LinkedHashMap<>();
        chunk.put("choices", List.of(choice));
        return chunk;
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
