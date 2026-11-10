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
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

public final class HarmovelaSink implements Sink {
    private static final HttpClient CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(30))
            .build();
    private static final DateTimeFormatter SECONDS =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")
                    .withZone(ZoneOffset.UTC);

    private final String baseUrl;
    private final String source;
    private final String specVersion;
    private final Transport transport;

    public HarmovelaSink(String baseUrl) {
        this(baseUrl, "praxo-core", "0.2", null);
    }

    public HarmovelaSink(String baseUrl, Transport transport) {
        this(baseUrl, "praxo-core", "0.2", transport);
    }

    public HarmovelaSink(
            String baseUrl,
            String source,
            String specVersion,
            Transport transport) {
        this.baseUrl = baseUrl == null ? "" : baseUrl.replaceAll("/+$", "");
        this.source = source == null || source.isEmpty() ? "praxo-core" : source;
        this.specVersion =
                specVersion == null || specVersion.isEmpty() ? "0.2" : specVersion;
        this.transport = transport == null ? HarmovelaSink::post : transport;
    }

    @Override
    public void emit(Event event) throws Exception {
        if (baseUrl.isEmpty()) {
            throw new IllegalArgumentException("harmovela: base URL is required");
        }
        String body = Json.stringify(envelope(event));
        HttpRequest request = new HttpRequest(
                "POST",
                baseUrl + "/events",
                Map.of("content-type", "application/json"),
                body);
        HttpResponse response = transport.send(request);
        if (response.status() < 200 || response.status() >= 300) {
            String text = response.body() == null ? "" : response.body();
            if (text.length() > 512) {
                text = text.substring(0, 512);
            }
            throw new IllegalStateException(
                    "harmovela: HTTP " + response.status() + ": " + text.strip());
        }
    }

    private Map<String, Object> envelope(Event event) {
        Instant at = instant(event.at());
        Map<String, Object> payload = new LinkedHashMap<>();
        if (event.data() != null) {
            payload.putAll(event.data());
        }
        if (event.sessionId() != null && !event.sessionId().isEmpty()) {
            payload.put("session_id", event.sessionId());
        }
        if (event.runId() != null && !event.runId().isEmpty()) {
            payload.put("run_id", event.runId());
        }
        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("spec_version", specVersion);
        envelope.put("id", eventId(event, at));
        envelope.put("type", event.type());
        envelope.put("source", source);
        envelope.put("created_at", rfc3339Nanos(at));
        envelope.put("payload", payload);
        return envelope;
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

    private static String eventId(Event event, Instant at) {
        String prefix = event.runId();
        if (prefix == null || prefix.isEmpty()) {
            prefix = event.sessionId();
        }
        if (prefix == null || prefix.isEmpty()) {
            prefix = "event";
        }
        long nanos = at.getEpochSecond() * 1_000_000_000L + at.getNano();
        return prefix + "-" + nanos;
    }

    private static String rfc3339Nanos(Instant at) {
        return String.format(
                Locale.ROOT,
                "%s.%09dZ",
                SECONDS.format(at),
                at.getNano());
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
