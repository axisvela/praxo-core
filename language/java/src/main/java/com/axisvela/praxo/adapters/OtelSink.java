package com.axisvela.praxo.adapters;

import com.axisvela.praxo.event.Event;
import com.axisvela.praxo.event.Sink;
import com.axisvela.praxo.util.Json;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpResponse.BodyHandlers;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class OtelSink implements Sink {
    private static final HttpClient CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(30))
            .build();

    private final String endpoint;
    private final String serviceName;
    private final Transport transport;
    private final List<String> allowedDataKeys;

    public OtelSink() {
        this("http://127.0.0.1:4318/v1/traces", "praxo-core", null, List.of());
    }

    public OtelSink(String endpoint, Transport transport) {
        this(endpoint, "praxo-core", transport, List.of());
    }

    public OtelSink(
            String endpoint,
            String serviceName,
            Transport transport,
            List<String> allowedDataKeys) {
        this.endpoint = endpoint == null || endpoint.isEmpty()
                ? "http://127.0.0.1:4318/v1/traces" : endpoint;
        this.serviceName = serviceName == null || serviceName.isEmpty()
                ? "praxo-core" : serviceName;
        this.transport = transport == null ? OtelSink::post : transport;
        this.allowedDataKeys = allowedDataKeys == null
                ? List.of() : List.copyOf(allowedDataKeys);
    }

    @Override
    public void emit(Event event) throws Exception {
        HttpRequest request = new HttpRequest(
                "POST",
                endpoint,
                Map.of("content-type", "application/json"),
                Json.stringify(payload(event)));
        HttpResponse response = transport.send(request);
        if (response.status() < 200 || response.status() >= 300) {
            String text = response.body() == null ? "" : response.body();
            if (text.length() > 512) {
                text = text.substring(0, 512);
            }
            throw new IllegalStateException(
                    "otel: HTTP " + response.status() + ": " + text.strip());
        }
    }

    private Map<String, Object> payload(Event event) {
        Instant at = instant(event.at());
        long nanos = at.getEpochSecond() * 1_000_000_000L + at.getNano();
        String key = String.join("|",
                nullToEmpty(event.sessionId()),
                nullToEmpty(event.runId()),
                event.type(),
                at.toString(),
                Json.stringify(event.data() == null ? Map.of() : event.data()));
        String traceId = hex(fnv1a(key, 0xcbf29ce484222325L))
                + hex(fnv1a(key, 0x84222325cbf29ce4L));
        String spanId = hex(fnv1a(key + "|span", 0x100000001b3L));

        List<Map<String, Object>> attributes = new ArrayList<>();
        attributes.add(attribute("praxo.event.type", event.type()));
        if (event.sessionId() != null && !event.sessionId().isEmpty()) {
            attributes.add(attribute("praxo.session.id", event.sessionId()));
        }
        if (event.runId() != null && !event.runId().isEmpty()) {
            attributes.add(attribute("praxo.run.id", event.runId()));
        }
        attributes.add(attribute("praxo.event.at", at.toString()));
        Map<String, Object> data = event.data() == null ? Map.of() : event.data();
        for (String name : allowedDataKeys) {
            if (data.containsKey(name)) {
                attributes.add(attribute(
                        "praxo.event.data." + name,
                        text(data.get(name))));
            }
        }

        Map<String, Object> span = new LinkedHashMap<>();
        span.put("traceId", traceId);
        span.put("spanId", spanId);
        span.put("name", "praxo." + event.type());
        span.put("kind", 1);
        span.put("startTimeUnixNano", Long.toUnsignedString(nanos));
        span.put("endTimeUnixNano", Long.toUnsignedString(nanos));
        span.put("attributes", attributes);

        Map<String, Object> scope = new LinkedHashMap<>();
        scope.put("name", "praxo-core");
        Map<String, Object> scopeSpan = new LinkedHashMap<>();
        scopeSpan.put("scope", scope);
        scopeSpan.put("spans", List.of(span));
        Map<String, Object> resource = new LinkedHashMap<>();
        resource.put("attributes",
                List.of(attribute("service.name", serviceName)));
        Map<String, Object> resourceSpan = new LinkedHashMap<>();
        resourceSpan.put("resource", resource);
        resourceSpan.put("scopeSpans", List.of(scopeSpan));
        Map<String, Object> root = new LinkedHashMap<>();
        root.put("resourceSpans", List.of(resourceSpan));
        return root;
    }

    private static Instant instant(String raw) {
        if (raw == null || raw.isEmpty()) {
            return Instant.now();
        }
        try {
            return Instant.parse(raw);
        } catch (DateTimeParseException error) {
            return Instant.now();
        }
    }

    private static String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private static Map<String, Object> attribute(String key, String value) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("key", key);
        Map<String, Object> wrapped = new LinkedHashMap<>();
        wrapped.put("stringValue", value);
        out.put("value", wrapped);
        return out;
    }

    private static String text(Object value) {
        return value instanceof String string ? string : Json.stringify(value);
    }

    private static long fnv1a(String text, long seed) {
        long value = seed;
        for (byte current : text.getBytes(StandardCharsets.UTF_8)) {
            value ^= current & 0xffL;
            value *= 0x100000001b3L;
        }
        return value;
    }

    private static String hex(long value) {
        return String.format(Locale.ROOT, "%016x", value);
    }

    private static HttpResponse post(HttpRequest request) throws Exception {
        java.net.http.HttpRequest.Builder builder =
                java.net.http.HttpRequest.newBuilder(URI.create(request.url()))
                        .timeout(Duration.ofSeconds(30))
                        .method(
                                request.method(),
                                java.net.http.HttpRequest.BodyPublishers.ofString(
                                        request.body(),
                                        StandardCharsets.UTF_8));
        for (Map.Entry<String, String> header : request.headers().entrySet()) {
            builder.header(header.getKey(), header.getValue());
        }
        java.net.http.HttpResponse<String> response =
                CLIENT.send(builder.build(), BodyHandlers.ofString());
        return new HttpResponse(response.statusCode(), response.body());
    }

    public interface Transport {
        HttpResponse send(HttpRequest request) throws Exception;
    }

    public record HttpRequest(
            String method,
            String url,
            Map<String, String> headers,
            String body) {
    }

    public record HttpResponse(int status, String body) {
    }
}
