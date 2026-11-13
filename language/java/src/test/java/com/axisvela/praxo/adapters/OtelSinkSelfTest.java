package com.axisvela.praxo.adapters;

import com.axisvela.praxo.event.Event;
import com.axisvela.praxo.util.Json;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class OtelSinkSelfTest {
    private OtelSinkSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        List<OtelSink.HttpRequest> calls = new ArrayList<>();
        OtelSink.Transport capture = request -> {
            calls.add(request);
            return new OtelSink.HttpResponse(200, "");
        };
        OtelSink sink = new OtelSink(
                "http://otel.test/v1/traces",
                "praxo-test",
                capture,
                List.of("name"));
        sink.emit(event());

        check(calls.size() == 1, "single request");
        OtelSink.HttpRequest request = calls.get(0);
        check(request.method().equals("POST"), "method");
        check(request.url().equals("http://otel.test/v1/traces"), "url");
        check(request.headers().get("content-type").equals("application/json"),
                "content type");
        Map<String, Object> payload = Json.object(request.body());
        List<Object> resourceSpans =
                Json.asArray(payload.get("resourceSpans"));
        Map<String, Object> resourceSpan =
                Json.asObject(resourceSpans.get(0));
        Map<String, Object> resource =
                Json.asObject(resourceSpan.get("resource"));
        List<Object> resourceAttributes =
                Json.asArray(resource.get("attributes"));
        Map<String, Object> service =
                Json.asObject(resourceAttributes.get(0));
        Map<String, Object> serviceValue =
                Json.asObject(service.get("value"));
        check(serviceValue.get("stringValue").equals("praxo-test"),
                "service name");

        Map<String, Object> scopeSpan =
                Json.asObject(Json.asArray(resourceSpan.get("scopeSpans")).get(0));
        Map<String, Object> span =
                Json.asObject(Json.asArray(scopeSpan.get("spans")).get(0));
        check(span.get("name").equals("praxo.tool.call"), "span name");
        check(((String) span.get("traceId")).length() == 32, "trace id");
        check(((String) span.get("spanId")).length() == 16, "span id");
        check(span.get("startTimeUnixNano").equals(span.get("endTimeUnixNano")),
                "timestamps");
        Map<String, String> attributes = new LinkedHashMap<>();
        for (Object item : Json.asArray(span.get("attributes"))) {
            Map<String, Object> entry = Json.asObject(item);
            attributes.put((String) entry.get("key"),
                    (String) Json.asObject(entry.get("value")).get("stringValue"));
        }
        check(attributes.get("praxo.event.type").equals("tool.call"),
                "event type");
        check(attributes.get("praxo.session.id").equals("s1"),
                "session id");
        check(attributes.get("praxo.run.id").equals("run-123"), "run id");
        check(attributes.get("praxo.event.data.name").equals("echo"),
                "allowed data");
        check(!attributes.containsKey("praxo.event.data.secret"),
                "data excluded by default");

        sink.emit(event());
        Map<String, Object> second = Json.object(calls.get(1).body());
        Map<String, Object> secondResourceSpan = Json.asObject(
                Json.asArray(second.get("resourceSpans")).get(0));
        Map<String, Object> secondScopeSpan = Json.asObject(
                Json.asArray(secondResourceSpan.get("scopeSpans")).get(0));
        Map<String, Object> secondSpan = Json.asObject(
                Json.asArray(secondScopeSpan.get("spans")).get(0));
        check(span.get("traceId").equals(secondSpan.get("traceId")),
                "deterministic trace id");
        check(span.get("spanId").equals(secondSpan.get("spanId")),
                "deterministic span id");

        OtelSink failing = new OtelSink(
                "http://otel.test/v1/traces",
                "praxo-test",
                value -> new OtelSink.HttpResponse(503, "down"),
                List.of());
        try {
            failing.emit(event());
            throw new AssertionError("expected non-2xx error");
        } catch (IllegalStateException error) {
            check(error.getMessage().contains("503"), "error status");
        }
        System.out.println("otel sink ok");
    }

    private static Event event() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("name", "echo");
        data.put("secret", "hidden");
        return new Event(
                "tool.call", "s1", "run-123", data, "2026-11-10T07:00:00Z");
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
