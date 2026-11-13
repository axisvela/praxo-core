module praxo.otel;

import std.conv : to;
import std.datetime : Clock, SysTime, UTC;
import std.file : remove, tempDir, write;
import std.format : format;
import std.json : JSONType, JSONValue;
import std.path : buildPath;
import std.process : execute;
import std.random : uniform;
import std.string : lastIndexOf, strip;

import praxo.errors : PraxoError;
import praxo.json : hasKey, stringify;
import praxo.models : Event;
import praxo.runtime : EventSink;

struct OtelResponse {
    int status;
    string body;
}

alias OtelTransport = OtelResponse delegate(string endpoint, string body,
    string[string] headers);

alias OtelClock = long delegate();

private long defaultClock() {
    return Clock.currTime(UTC()).stdTime * 100;
}

private string timestampText(long nanos) {
    auto value = SysTime.fromUnixTime(nanos / 1_000_000_000L, UTC());
    return format("%04d-%02d-%02dT%02d:%02d:%02d.%09dZ",
        value.year, cast(int) value.month, value.day,
        value.hour, value.minute, value.second,
        cast(int) (nanos % 1_000_000_000L));
}

private string bounded(string body) {
    return body.length > 512 ? body[0 .. 512] : body;
}

private string nonNull(string value) {
    return value is null ? "" : value;
}

private JSONValue attribute(string key, string value) {
    JSONValue[string] wrapped;
    wrapped["stringValue"] = JSONValue(value);
    JSONValue[string] item;
    item["key"] = JSONValue(key);
    item["value"] = JSONValue(wrapped);
    return JSONValue(item);
}

private string textValue(JSONValue value) {
    return value.type == JSONType.string ? value.str : stringify(value);
}

private ulong fnv1a(string text, ulong seed) {
    ulong value = seed;
    foreach (byte current; cast(const(ubyte)[]) text) {
        value ^= current;
        value *= 0x100000001b3UL;
    }
    return value;
}

private OtelResponse post(string endpoint, string body, string[string] headers) {
    auto input = buildPath(tempDir(),
        "praxo-otel-" ~ uniform(0, 2_000_000_000).to!string ~ ".json");
    write(input, body);
    scope(exit) remove(input);
    string[] command = ["curl", "-sS", "-X", "POST"];
    foreach (key, value; headers) {
        command ~= ["-H", key ~ ": " ~ value];
    }
    command ~= ["--data-binary", "@" ~ input, "-w", "\n%{http_code}", endpoint];
    auto result = execute(command);
    auto text = result.output;
    auto index = text.lastIndexOf('\n');
    int status = 0;
    string responseBody = text;
    if (index >= 0) {
        responseBody = text[0 .. index];
        try {
            status = strip(text[index + 1 .. $]).to!int;
        } catch (Exception) {
            status = 0;
        }
    }
    return OtelResponse(status, responseBody);
}

class OtelSink : EventSink {
    string endpoint;
    string serviceName;
    string[] allowedDataKeys;
    OtelTransport transport;
    OtelClock clock;

    this(string endpoint, string serviceName = "praxo-core",
         string[] allowedDataKeys = null, OtelTransport transport = null,
         OtelClock clock = null) {
        this.endpoint = endpoint;
        this.serviceName = serviceName.length == 0 ? "praxo-core" : serviceName;
        this.allowedDataKeys = allowedDataKeys is null ? [] : allowedDataKeys;
        this.transport = transport;
        this.clock = clock;
    }

    void emit(Event event) {
        auto target = endpoint is null ? "" : endpoint.strip();
        if (target.length == 0) {
            throw new PraxoError("OTEL_URL", "otel: endpoint is required");
        }
        auto nanos = clock is null ? defaultClock() : clock();
        auto body = payload(event, nanos);
        string[string] headers;
        headers["content-type"] = "application/json";
        auto response = transport is null
            ? post(target, body, headers)
            : transport(target, body, headers);
        if (response.status >= 200 && response.status < 300) return;
        throw new PraxoError("OTEL_HTTP",
            "otel: HTTP " ~ response.status.to!string ~ ": " ~ bounded(response.body).strip());
    }

    private string payload(Event event, long nanos) {
        auto stamp = timestampText(nanos);
        auto data = event.data.type == JSONType.object
            ? event.data
            : JSONValue(cast(JSONValue[string]) null);
        auto dataText = event.data.type == JSONType.null_
            ? "{}"
            : stringify(event.data);
        auto key = nonNull(event.sessionId) ~ "|" ~ nonNull(event.runId) ~ "|"
            ~ nonNull(event.type) ~ "|" ~ stamp ~ "|" ~ dataText;
        auto traceId = format("%016x%016x",
            fnv1a(key, 0xcbf29ce484222325UL),
            fnv1a(key, 0x84222325cbf29ce4UL));
        auto spanId = format("%016x", fnv1a(key ~ "|span", 0x100000001b3UL));

        JSONValue[] attributes;
        attributes ~= attribute("praxo.event.type", nonNull(event.type));
        if (nonNull(event.sessionId).length > 0) {
            attributes ~= attribute("praxo.session.id", event.sessionId);
        }
        if (nonNull(event.runId).length > 0) {
            attributes ~= attribute("praxo.run.id", event.runId);
        }
        attributes ~= attribute("praxo.event.at", stamp);
        foreach (name; allowedDataKeys) {
            if (!hasKey(data, name)) continue;
            attributes ~= attribute("praxo.event.data." ~ name, textValue(data.object[name]));
        }

        JSONValue[string] span;
        span["traceId"] = JSONValue(traceId);
        span["spanId"] = JSONValue(spanId);
        span["name"] = JSONValue("praxo." ~ nonNull(event.type));
        span["kind"] = JSONValue(1);
        span["startTimeUnixNano"] = JSONValue(nanos.to!string);
        span["endTimeUnixNano"] = JSONValue(nanos.to!string);
        span["attributes"] = JSONValue(attributes);

        JSONValue[string] scopeValue;
        scopeValue["name"] = JSONValue("praxo-core");
        JSONValue[string] scopeSpan;
        scopeSpan["scope"] = JSONValue(scopeValue);
        scopeSpan["spans"] = JSONValue([JSONValue(span)]);

        JSONValue[string] resource;
        resource["attributes"] = JSONValue([attribute("service.name", serviceName)]);
        JSONValue[string] resourceSpan;
        resourceSpan["resource"] = JSONValue(resource);
        resourceSpan["scopeSpans"] = JSONValue([JSONValue(scopeSpan)]);

        JSONValue[string] root;
        root["resourceSpans"] = JSONValue([JSONValue(resourceSpan)]);
        return stringify(JSONValue(root));
    }
}
