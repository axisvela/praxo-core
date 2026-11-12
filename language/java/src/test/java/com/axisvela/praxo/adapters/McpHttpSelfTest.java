package com.axisvela.praxo.adapters;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.util.Json;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

public final class McpHttpSelfTest {
    private McpHttpSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        testHandshakeListCallAndDelete();
        System.out.println("handshake test passed");
        testSseResponse();
        System.out.println("sse test passed");
        testRejectsRemotePlainHttp();
        System.out.println("MCP Streamable HTTP self-test passed");
        System.exit(0);
    }

    private static void testHandshakeListCallAndDelete() throws Exception {
        AtomicBoolean deleted = new AtomicBoolean();
        List<Map<String, String>> headers = new ArrayList<>();
        System.out.println("starting server");
        HttpServer server = startServer(deleted, headers, false);
        System.out.println("server started");
        try {
            String endpoint = "http://127.0.0.1:"
                    + server.getAddress().getPort() + "/mcp";
            McpStreamableHttpTransport transport =
                    new McpStreamableHttpTransport(endpoint);
            System.out.println("connecting");
            try (McpClient client = McpClient.connect(transport)) {
                System.out.println("connected");
                require("2025-03-26".equals(client.protocolVersion()),
                        "protocol version");
                List<McpTool> tools = client.listTools();
                require(tools.size() == 1 && tools.get(0).name().equals("echo"),
                        "tool names");
                require("http-ok".equals(client.callTool(
                        "echo", Map.of("text", "hi"))), "tool call");
            }
            require(deleted.get(), "DELETE was not sent");
            Map<String, String> listed = headers.stream()
                    .filter(item -> "sess-1".equals(item.get("mcp-session-id")))
                    .findFirst()
                    .orElseThrow();
            require("sess-1".equals(listed.get("mcp-session-id")),
                    "session header");
            require("2025-03-26".equals(listed.get("mcp-protocol-version")),
                    "protocol header");
        } finally {
            server.stop(0);
        }
    }

    private static void testSseResponse() throws Exception {
        HttpServer server = startServer(new AtomicBoolean(), new ArrayList<>(), true);
        try {
            String endpoint = "http://127.0.0.1:"
                    + server.getAddress().getPort() + "/mcp";
            McpStreamableHttpTransport transport =
                    new McpStreamableHttpTransport(endpoint);
            try (McpClient client = McpClient.connect(transport)) {
                require("sse-ok".equals(client.callTool(
                        "echo", Map.of("text", "hi"))), "sse result");
            }
        } finally {
            server.stop(0);
        }
    }

    private static void testRejectsRemotePlainHttp() {
        boolean rejected = false;
        try {
            new McpStreamableHttpTransport("http://example.com/mcp");
        } catch (PraxoException error) {
            rejected = error.code.equals("MCP_TRANSPORT");
        }
        require(rejected, "remote plain HTTP was not rejected");
    }

    private static HttpServer startServer(
            AtomicBoolean deleted,
            List<Map<String, String>> headers,
            boolean sse) throws IOException {
        HttpServer server = HttpServer.create(
                new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/mcp", exchange -> {
            System.out.println("request " + exchange.getRequestMethod());
            if ("DELETE".equals(exchange.getRequestMethod())) {
                deleted.set(true);
                respond(exchange, 200, "application/json", "");
                return;
            }
            Map<String, Object> message = Json.object(new String(
                    exchange.getRequestBody().readAllBytes(),
                    StandardCharsets.UTF_8));
            Map<String, String> captured = new LinkedHashMap<>();
            captured.put("mcp-session-id",
                    exchange.getRequestHeaders().getFirst("Mcp-Session-Id"));
            captured.put("mcp-protocol-version",
                    exchange.getRequestHeaders().getFirst("Mcp-Protocol-Version"));
            headers.add(captured);
            String method = (String) message.get("method");
            if (method == null) {
                respond(exchange, 400, "application/json", "{}");
                return;
            }
            if (method.equals("initialize")) {
                exchange.getResponseHeaders().add("Mcp-Session-Id", "sess-1");
                respond(exchange, 200, "application/json", Json.stringify(
                        response(message, new LinkedHashMap<>(Map.of(
                                "protocolVersion", "2025-03-26",
                                "capabilities", Map.of(),
                                "serverInfo", Map.of(
                                        "name", "fake-http",
                                        "version", "1"))))));
                return;
            }
            if (method.startsWith("notifications/")) {
                respond(exchange, 202, "application/json", "");
                return;
            }
            if (method.equals("tools/list")) {
                Map<String, Object> tool = new LinkedHashMap<>();
                tool.put("name", "echo");
                tool.put("description", "Echo input");
                tool.put("inputSchema", Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "text", Map.of("type", "string")),
                        "required", List.of("text")));
                respond(exchange, 200, "application/json", Json.stringify(
                        response(message, Map.of("tools", List.of(tool)))));
                return;
            }
            if (method.equals("tools/call")) {
                Map<String, Object> result = response(message, Map.of(
                        "content", List.of(Map.of(
                                "type", "text",
                                "text", sse ? "sse-ok" : "http-ok"))));
                if (sse) {
                    respond(exchange, 200, "text/event-stream",
                            "event: message\ndata: "
                                    + Json.stringify(result) + "\n\n");
                } else {
                    respond(exchange, 200, "application/json",
                            Json.stringify(result));
                }
                return;
            }
            respond(exchange, 200, "application/json", Json.stringify(
                    response(message, Map.of())));
        });
        server.start();
        return server;
    }

    private static Map<String, Object> response(
            Map<String, Object> request,
            Map<String, Object> result) {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("jsonrpc", "2.0");
        response.put("id", request.get("id"));
        response.put("result", result);
        return response;
    }

    private static void respond(
            HttpExchange exchange,
            int status,
            String contentType,
            String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", contentType);
        exchange.sendResponseHeaders(status, bytes.length == 0 ? -1 : bytes.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(bytes);
        }
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
