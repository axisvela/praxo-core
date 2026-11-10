package com.axisvela.praxo.adapters;

import com.axisvela.praxo.event.Event;
import com.axisvela.praxo.util.Json;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class HarmovelaSinkSelfTest {
    private HarmovelaSinkSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        List<HarmovelaSink.HttpRequest> calls = new ArrayList<>();
        HarmovelaSink.Transport capture = request -> {
            calls.add(request);
            return new HarmovelaSink.HttpResponse(201, "");
        };
        HarmovelaSink sink = new HarmovelaSink(
                "http://harmovela.test/aep/api/", capture);
        sink.emit(event());

        check(calls.size() == 1, "single request");
        HarmovelaSink.HttpRequest request = calls.get(0);
        check(request.method().equals("POST"), "method");
        check(request.url().equals("http://harmovela.test/aep/api/events"), "path");
        check(request.headers().get("content-type").equals("application/json"),
                "content type");
        Map<String, Object> envelope = Json.object(request.body());
        check(envelope.get("spec_version").equals("0.2"), "spec version");
        check(envelope.get("id").equals("run-123-1794294000000000000"), "id");
        check(envelope.get("type").equals("tool.call"), "type");
        check(envelope.get("source").equals("praxo-core"), "source");
        check(envelope.get("created_at").equals("2026-11-10T07:00:00.000000000Z"),
                "created at");
        Map<String, Object> payload = Json.asObject(envelope.get("payload"));
        check(payload.get("name").equals("echo"), "payload data");
        check(payload.get("session_id").equals("s1"), "payload session");
        check(payload.get("run_id").equals("run-123"), "payload run");

        HarmovelaSink custom = new HarmovelaSink(
                "http://harmovela.test", "custom", "0.3", capture);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("name", "echo");
        data.put("session_id", "event-side");
        data.put("run_id", "old");
        custom.emit(new Event(
                "tool.call", "s1", "", data, "2026-11-10T07:00:00Z"));
        Map<String, Object> merged = Json.object(calls.get(1).body());
        check(merged.get("source").equals("custom"), "custom source");
        check(merged.get("spec_version").equals("0.3"), "custom spec");
        check(((String) merged.get("id")).startsWith("s1-"), "session id prefix");
        Map<String, Object> mergedPayload =
                Json.asObject(merged.get("payload"));
        check(mergedPayload.get("session_id").equals("s1"), "session override");
        check(mergedPayload.get("run_id").equals("old"), "data run retained");

        for (int status : new int[] { 200, 201, 204, 299 }) {
            HarmovelaSink accepted = new HarmovelaSink(
                    "http://harmovela.test",
                    requestValue -> new HarmovelaSink.HttpResponse(status, ""));
            accepted.emit(event());
        }

        HarmovelaSink failing = new HarmovelaSink(
                "http://harmovela.test",
                requestValue -> new HarmovelaSink.HttpResponse(
                        503, "service down ".repeat(100)));
        try {
            failing.emit(event());
            throw new AssertionError("expected non-2xx error");
        } catch (IllegalStateException error) {
            check(error.getMessage().contains("503"), "error status");
            check(error.getMessage().contains("service down"), "error body");
            check(error.getMessage().length() <= 600, "bounded error body");
        }
        System.out.println("harmovela sink ok");
    }

    private static Event event() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("name", "echo");
        return new Event(
                "tool.call", "s1", "run-123", data, "2026-11-10T07:00:00Z");
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
