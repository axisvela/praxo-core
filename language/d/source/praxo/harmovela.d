module praxo.harmovela;

import std.conv : to;
import std.datetime : Clock, SysTime, UTC;
import std.file : remove, tempDir, write;
import std.format : format;
import std.json : JSONType, JSONValue;
import std.path : buildPath;
import std.process : execute;
import std.random : uniform;
import std.string : lastIndexOf, strip, stripRight;
import praxo.errors : PraxoError;
import praxo.json : stringify;
import praxo.models : Event;
import praxo.runtime : EventSink;

struct HarmovelaResponse {
    int status;
    string body;
}

struct HarmovelaTimestamp {
    long seconds;
    int nanos;
}

alias HarmovelaTransport = HarmovelaResponse delegate(string baseUrl, string path,
    string body, string[string] headers);

alias HarmovelaClock = HarmovelaTimestamp delegate();

HarmovelaTimestamp defaultClock() {
    auto now = Clock.currTime(UTC());
    long total = now.stdTime;
    return HarmovelaTimestamp(total / 10_000_000, cast(int) ((total % 10_000_000) * 100));
}

string rfc3339Nano(HarmovelaTimestamp at) {
    auto value = SysTime.fromUnixTime(at.seconds, UTC());
    return format("%04d-%02d-%02dT%02d:%02d:%02d.%09dZ",
        value.year, cast(int) value.month, value.day,
        value.hour, value.minute, value.second, at.nanos);
}

string eventId(Event event, HarmovelaTimestamp at) {
    string prefix = event.runId;
    if (prefix.length == 0) prefix = event.sessionId;
    if (prefix.length == 0) prefix = "event";
    long stamp = at.seconds * 1_000_000_000L + at.nanos;
    return prefix ~ "-" ~ stamp.to!string;
}

string bounded(string body) {
    return body.length > 1024 ? body[0 .. 1024] : body;
}

HarmovelaResponse post(string baseUrl, string path, string body, string[string] headers) {
    auto input = buildPath(tempDir(),
        "praxo-harmovela-" ~ uniform(0, 2_000_000_000).to!string ~ ".json");
    write(input, body);
    scope(exit) remove(input);
    auto result = execute([
        "curl", "-sS", "-X", "POST", "-H", "content-type: application/json",
        "--data-binary", "@" ~ input, "-w", "\n%{http_code}", baseUrl ~ path,
    ]);
    auto text = result.output;
    auto index = text.lastIndexOf('\n');
    int status = 0;
    string responseBody = text;
    if (index >= 0) {
        auto statusText = strip(text[index + 1 .. $]);
        try {
            status = statusText.to!int;
        } catch (Exception) {
            status = 0;
        }
        responseBody = text[0 .. index];
    }
    return HarmovelaResponse(status, responseBody);
}

class HarmovelaSink : EventSink {
    string baseUrl;
    string source;
    string specVersion;
    HarmovelaTransport transport;
    HarmovelaClock clock;

    this(string baseUrl, string source = "praxo-core", string specVersion = "0.2",
         HarmovelaTransport transport = null, HarmovelaClock clock = null) {
        this.baseUrl = baseUrl.stripRight("/");
        this.source = source.length == 0 ? "praxo-core" : source;
        this.specVersion = specVersion.length == 0 ? "0.2" : specVersion;
        this.transport = transport;
        this.clock = clock;
    }

    void emit(Event event) {
        if (baseUrl.length == 0) {
            throw new PraxoError("HARMOVELA_URL", "harmovela: base URL is required");
        }
        auto at = clock is null ? defaultClock() : clock();
        JSONValue[string] payload;
        if (event.data.type == JSONType.object) {
            foreach (key, value; event.data.object) {
                payload[key] = value;
            }
        }
        if (event.sessionId.length > 0) {
            payload["session_id"] = JSONValue(event.sessionId);
        }
        if (event.runId !is null && event.runId.length > 0) {
            payload["run_id"] = JSONValue(event.runId);
        }
        JSONValue[string] envelope;
        envelope["spec_version"] = JSONValue(specVersion);
        envelope["id"] = JSONValue(eventId(event, at));
        envelope["type"] = JSONValue(event.type);
        envelope["source"] = JSONValue(source);
        envelope["created_at"] = JSONValue(rfc3339Nano(at));
        envelope["payload"] = JSONValue(payload);
        auto body = stringify(JSONValue(envelope));
        string[string] headers;
        headers["content-type"] = "application/json";
        auto response = transport is null
            ? post(baseUrl, "/events", body, headers)
            : transport(baseUrl, "/events", body, headers);
        if (response.status >= 200 && response.status < 300) return;
        throw new PraxoError("HARMOVELA_HTTP",
            "harmovela: HTTP " ~ response.status.to!string ~ ": " ~ bounded(response.body));
    }
}
