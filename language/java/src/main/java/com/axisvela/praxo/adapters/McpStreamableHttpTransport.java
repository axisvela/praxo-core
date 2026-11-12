package com.axisvela.praxo.adapters;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.util.Json;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

public final class McpStreamableHttpTransport implements McpTransport {
    private static final Object CLOSED = new Object();
    private static final String DEFAULT_PROTOCOL_VERSION = "2025-03-26";

    private final String endpoint;
    private final Map<String, String> headers;
    private final Duration timeout;
    private final HttpClient client;
    private final BlockingQueue<Object> incoming = new LinkedBlockingQueue<>();
    private final AtomicBoolean closed = new AtomicBoolean();

    private String protocolVersion;
    private String sessionId = "";
    private volatile boolean started;

    public McpStreamableHttpTransport(String endpoint) {
        this(endpoint, Map.of(), DEFAULT_PROTOCOL_VERSION,
                Duration.ofSeconds(30), null);
    }

    public McpStreamableHttpTransport(
            String endpoint,
            Map<String, String> headers,
            String protocolVersion,
            Duration timeout,
            HttpClient client) {
        URI uri = URI.create(endpoint);
        String scheme = uri.getScheme();
        if (scheme == null
                || (!scheme.equals("http") && !scheme.equals("https"))) {
            throw PraxoException.mcpTransport("mcp: invalid HTTP endpoint");
        }
        if (scheme.equals("http") && !isLoopback(uri.getHost())) {
            throw PraxoException.mcpTransport(
                    "mcp: HTTP endpoint must use HTTPS");
        }
        this.endpoint = endpoint;
        this.headers = headers == null ? Map.of() : Map.copyOf(headers);
        this.protocolVersion = protocolVersion == null || protocolVersion.isBlank()
                ? DEFAULT_PROTOCOL_VERSION
                : protocolVersion;
        this.timeout = timeout == null ? Duration.ofSeconds(30) : timeout;
        this.client = client == null ? HttpClient.newHttpClient() : client;
    }

    @Override
    public void start() {
        if (closed.get()) {
            throw PraxoException.mcpClosed("mcp: client is closed");
        }
        started = true;
    }

    @Override
    public void send(Map<String, Object> message) {
        if (!started || closed.get()) {
            throw PraxoException.mcpTransport("mcp: transport is closed");
        }
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(endpoint))
                .timeout(timeout)
                .header("content-type", "application/json")
                .header("accept", "application/json, text/event-stream")
                .header("mcp-protocol-version", protocolVersion)
                .POST(HttpRequest.BodyPublishers.ofString(
                        Json.stringify(message), StandardCharsets.UTF_8));
        if (!sessionId.isEmpty()) {
            builder.header("mcp-session-id", sessionId);
        }
        headers.forEach(builder::header);
        HttpResponse<String> response;
        try {
            response = client.send(
                    builder.build(),
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        } catch (IOException error) {
            throw PraxoException.mcpTransport(
                    "mcp: HTTP transport failed: " + error.getMessage());
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            throw PraxoException.mcpCancelled("mcp: HTTP request cancelled");
        }
        response.headers().firstValue("mcp-session-id")
                .filter(value -> !value.isEmpty())
                .ifPresent(value -> sessionId = value);
        int status = response.statusCode();
        if (status == 202 || status == 204) {
            return;
        }
        if (status < 200 || status >= 300) {
            throw PraxoException.mcpTransport(
                    "mcp: HTTP " + status + ": " + truncate(response.body()));
        }
        String contentType = response.headers()
                .firstValue("content-type")
                .orElse("");
        List<Map<String, Object>> messages = contentType
                .toLowerCase()
                .contains("text/event-stream")
                ? parseSse(response.body())
                : parseJson(response.body());
        for (Map<String, Object> item : messages) {
            if (item.get("result") instanceof Map<?, ?> result) {
                Object version = result.get("protocolVersion");
                if (version instanceof String text && !text.isEmpty()) {
                    protocolVersion = text;
                }
            }
            incoming.offer(item);
        }
    }

    @Override
    public Map<String, Object> receive() {
        for (;;) {
            Object item;
            try {
                item = incoming.poll(100, TimeUnit.MILLISECONDS);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                return null;
            }
            if (item == CLOSED) {
                return null;
            }
            if (item != null) {
                @SuppressWarnings("unchecked")
                Map<String, Object> message = (Map<String, Object>) item;
                return message;
            }
            if (closed.get()) {
                return null;
            }
        }
    }

    @Override
    public boolean isRunning() {
        return started && !closed.get();
    }

    @Override
    public long pid() {
        return -1;
    }

    @Override
    public void close() {
        if (!closed.compareAndSet(false, true)) {
            return;
        }
        if (!sessionId.isEmpty()) {
            try {
                HttpRequest.Builder builder = HttpRequest.newBuilder(
                                URI.create(endpoint))
                        .timeout(timeout)
                        .header("mcp-protocol-version", protocolVersion)
                        .header("mcp-session-id", sessionId)
                        .DELETE();
                headers.forEach(builder::header);
                client.send(
                        builder.build(),
                        HttpResponse.BodyHandlers.discarding());
            } catch (Exception ignored) {
            }
        }
        incoming.offer(CLOSED);
    }

    private List<Map<String, Object>> parseJson(String text) {
        if (text == null || text.isBlank()) {
            return List.of();
        }
        Object value;
        try {
            value = Json.parse(text);
        } catch (RuntimeException error) {
            throw PraxoException.mcpProtocol("mcp: server sent invalid JSON");
        }
        if (value instanceof List<?> list) {
            List<Map<String, Object>> messages = new ArrayList<>();
            for (Object item : list) {
                messages.add(Json.asObject(item));
            }
            return messages;
        }
        return List.of(Json.asObject(value));
    }

    private List<Map<String, Object>> parseSse(String text) {
        List<Map<String, Object>> messages = new ArrayList<>();
        List<String> data = new ArrayList<>();
        for (String raw : text.split("\\R", -1)) {
            String line = raw.endsWith("\r")
                    ? raw.substring(0, raw.length() - 1)
                    : raw;
            if (line.isEmpty()) {
                if (!data.isEmpty()) {
                    messages.add(Json.object(String.join("\n", data)));
                    data.clear();
                }
                continue;
            }
            if (line.startsWith(":")) {
                continue;
            }
            if (line.startsWith("data:")) {
                data.add(line.substring(5).stripLeading());
            }
        }
        if (!data.isEmpty()) {
            messages.add(Json.object(String.join("\n", data)));
        }
        return messages;
    }

    private static String truncate(String text) {
        if (text == null) {
            return "";
        }
        return text.length() <= 512 ? text : text.substring(0, 512);
    }

    private static boolean isLoopback(String host) {
        if (host == null) {
            return false;
        }
        String value = host.replace("[", "").replace("]", "");
        return value.equalsIgnoreCase("localhost")
                || value.equals("127.0.0.1")
                || value.equals("::1")
                || value.startsWith("127.");
    }
}
