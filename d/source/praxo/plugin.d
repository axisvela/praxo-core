module praxo.plugin;

import std.algorithm.searching : canFind;
import std.conv : to;
import std.string : strip;
import std.regex : regex, matchFirst;
import praxo.errors : PraxoError;
import praxo.json;

struct PluginManifest {
    long schemaVersion;
    string id;
    string versionValue;
    string kind;
    JSONValue entrypoint;
    string protocol;
    string[] capabilities;
    JSONValue permissions;
    JSONValue limits;
    string isolation;
    JSONValue health;
}

private immutable string[] KINDS = [
    "tool.provider.v1", "model.provider.v1", "policy.provider.v1",
    "memory.provider.v1", "sandbox.provider.v1",
];
private immutable string[] TOP_KEYS = [
    "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
    "capabilities", "permissions", "limits", "isolation", "health",
    "signature", "sbom",
];
private immutable string[] ENTRYPOINT_KEYS = ["type", "command", "module", "image", "args", "dir"];
private immutable string[] PERMISSION_KEYS = ["filesystem", "network", "env"];
private immutable string[] LIMIT_KEYS = ["memoryMB", "cpuMillis", "timeoutMs", "maxInflight"];
private immutable string[] HEALTH_KEYS = ["method", "intervalMs"];
private immutable string[] SIGNATURE_KEYS = ["algorithm", "keyId"];

private void fail(string message) {
    throw new PraxoError("PLUGIN_INVALID", message);
}

private void checkKeys(JSONValue value, const string[] allowed, string where) {
    foreach (key, _; value.object) {
        if (!allowed.canFind(key)) fail("plugin: manifest: unknown field " ~ key ~ " in " ~ where);
    }
}

private JSONValue asObject(JSONValue value, string where) {
    if (value.type == JSONType.null_) return JSONValue(cast(JSONValue[string]) null);
    if (value.type != JSONType.object) fail("plugin: manifest: " ~ where ~ " must be an object");
    return value;
}

private string asString(JSONValue value, string where) {
    if (value.type != JSONType.string) fail("plugin: manifest: " ~ where ~ " must be a string");
    return value.str;
}

private long asInt(JSONValue value, string where) {
    if (value.type == JSONType.integer) return value.integer;
    if (value.type == JSONType.uinteger) return cast(long) value.uinteger;
    if (value.type == JSONType.float_ && value.floating == cast(long) value.floating) return cast(long) value.floating;
    fail("plugin: manifest: " ~ where ~ " must be an integer");
    return 0;
}

private bool textPresent(JSONValue value) {
    return value.type == JSONType.string && value.str.length > 0;
}

PluginManifest parseManifest(string raw) {
    if (raw.strip().length == 0) fail("plugin: manifest is empty");
    JSONValue root;
    try {
        root = parse(raw);
    } catch (Exception error) {
        fail("plugin: manifest: " ~ error.msg);
    }
    if (root.type != JSONType.object) fail("plugin: manifest must be an object");
    checkKeys(root, TOP_KEYS, "manifest");
    auto schemaVersion = asInt(get(root, "schemaVersion"), "schemaVersion");
    if (schemaVersion != 1) fail("plugin: manifest: schemaVersion = " ~ schemaVersion.to!string ~ ", want 1");
    auto id = asString(get(root, "id"), "id");
    if (!matchFirst(id, regex(`^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$`))) {
        fail("plugin: manifest: id " ~ id ~ " is not reverse-DNS");
    }
    auto versionValue = asString(get(root, "version"), "version");
    if (!matchFirst(versionValue, regex(`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$`))) {
        fail("plugin: manifest: version " ~ versionValue ~ " is not semver");
    }
    auto kind = asString(get(root, "kind"), "kind");
    if (!KINDS.canFind(kind)) fail("plugin: manifest: kind " ~ kind ~ " is not a known contract");
    auto protocol = asString(get(root, "protocol"), "protocol");
    if (protocol != "jsonrpc-2") fail("plugin: manifest: protocol = " ~ protocol ~ ", want jsonrpc-2");
    auto entrypoint = asObject(get(root, "entrypoint"), "entrypoint");
    checkKeys(entrypoint, ENTRYPOINT_KEYS, "entrypoint");
    auto entryType = asString(get(entrypoint, "type"), "entrypoint.type");
    string required;
    if (entryType == "process") required = "command";
    else if (entryType == "wasm") required = "module";
    else if (entryType == "container") required = "image";
    else fail("plugin: manifest: unknown entrypoint type " ~ entryType);
    if (!textPresent(get(entrypoint, required))) fail("plugin: manifest: " ~ entryType ~ " entrypoint requires " ~ required);
    auto isolation = asString(get(root, "isolation"), "isolation");
    if (isolation != entryType) fail("plugin: manifest: isolation " ~ isolation ~ " does not match entrypoint " ~ entryType);
    auto permissions = asObject(get(root, "permissions"), "permissions");
    checkKeys(permissions, PERMISSION_KEYS, "permissions");
    auto limits = asObject(get(root, "limits"), "limits");
    checkKeys(limits, LIMIT_KEYS, "limits");
    foreach (key, value; limits.object) {
        if (asInt(value, "limits." ~ key) < 0) fail("plugin: manifest: limits must not be negative");
    }
    auto health = asObject(get(root, "health"), "health");
    checkKeys(health, HEALTH_KEYS, "health");
    if (hasKey(root, "signature")) {
        auto signature = asObject(get(root, "signature"), "signature");
        checkKeys(signature, SIGNATURE_KEYS, "signature");
        if (!textPresent(get(signature, "algorithm")) || !textPresent(get(signature, "keyId"))) {
            fail("plugin: manifest: signature requires algorithm and keyId");
        }
    }
    string[] capabilities;
    if (hasKey(root, "capabilities")) {
        auto rawCapabilities = get(root, "capabilities");
        if (rawCapabilities.type != JSONType.array) fail("plugin: manifest: capabilities must be an array");
        foreach (item; rawCapabilities.array) {
            auto capability = asString(item, "capabilities");
            if (capability.length == 0) fail("plugin: manifest: capability must not be empty");
            if (capabilities.canFind(capability)) fail("plugin: manifest: duplicate capability");
            capabilities ~= capability;
        }
    }
    return PluginManifest(schemaVersion, id, versionValue, kind, entrypoint, protocol,
        capabilities, permissions, limits, isolation, health);
}
