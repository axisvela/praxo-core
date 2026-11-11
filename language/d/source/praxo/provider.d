module praxo.provider;

import std.conv : to;
import std.file : remove, tempDir, write;
import std.format : format;
import std.json : JSONType, JSONValue;
import std.path : buildPath;
import std.process : execute;
import std.random : uniform;
import std.string : lastIndexOf, strip;

import praxo.errors : PraxoError;
import praxo.json : parse, stringify;

alias ProviderTransport = JSONValue delegate(string path, JSONValue payload);

JSONValue postJSON(string baseUrl, string path, JSONValue payload, string[string] headers) {
    auto input = buildPath(tempDir(),
        "praxo-provider-" ~ uniform(0, 2_000_000_000).to!string ~ ".json");
    write(input, stringify(payload));
    scope(exit) remove(input);
    string[] command = ["curl", "-sS", "-X", "POST"];
    foreach (key, value; headers) {
        command ~= ["-H", key ~ ": " ~ value];
    }
    command ~= ["--data-binary", "@" ~ input, "-w", "\n%{http_code}", baseUrl ~ path];
    auto result = execute(command);
    auto text = result.output;
    auto index = text.lastIndexOf('\n');
    int status = 0;
    string body = text;
    if (index >= 0) {
        body = text[0 .. index];
        try {
            status = strip(text[index + 1 .. $]).to!int;
        } catch (Exception) {
            status = 0;
        }
    }
    if (status < 200 || status >= 300) {
        throw new PraxoError("PROVIDER_HTTP",
            "provider returned HTTP " ~ status.to!string ~ ": " ~ bounded(body));
    }
    try {
        return parse(body);
    } catch (Exception) {
        throw new PraxoError("PROVIDER_JSON", "provider returned invalid JSON");
    }
}

string bounded(string body) {
    return body.length > 512 ? body[0 .. 512] : body;
}

JSONValue objectOf(JSONValue[string] value) {
    return JSONValue(value);
}

JSONValue emptyObject() {
    JSONValue[string] value;
    return JSONValue(value);
}

JSONValue arrayOf(JSONValue[] value) {
    return JSONValue(value);
}

JSONValue toolArguments(JSONValue value) {
    if (value.type == JSONType.object) return value;
    return emptyObject();
}

string contentText(JSONValue value) {
    if (value.type == JSONType.string) return value.str;
    return "";
}
