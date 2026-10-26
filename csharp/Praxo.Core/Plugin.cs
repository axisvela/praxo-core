using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Praxo.Core;

public sealed class PluginManifest
{
    public int SchemaVersion { get; set; }

    public string Id { get; set; } = "";

    public string Version { get; set; } = "";

    public string Kind { get; set; } = "";

    public JsonObject Entrypoint { get; set; } = new();

    public string Protocol { get; set; } = "";

    public List<string> Capabilities { get; set; } = new();

    public JsonObject Permissions { get; set; } = new();

    public JsonObject Limits { get; set; } = new();

    public string Isolation { get; set; } = "";

    public JsonObject Health { get; set; } = new();

    public JsonObject? Signature { get; set; }

    public string Sbom { get; set; } = "";
}

public static class Plugin
{
    public static readonly string[] Kinds =
    {
        "tool.provider.v1", "model.provider.v1", "policy.provider.v1",
        "memory.provider.v1", "sandbox.provider.v1",
    };

    private static readonly Regex ReverseDns = new(
        "^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$",
        RegexOptions.Compiled);

    private static readonly Regex Semver = new(
        "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?$",
        RegexOptions.Compiled);

    private static readonly HashSet<string> TopKeys = new()
    {
        "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
        "capabilities", "permissions", "limits", "isolation", "health",
        "signature", "sbom",
    };

    private static readonly HashSet<string> EntrypointKeys = new()
    {
        "type", "command", "module", "image", "args", "dir",
    };

    private static readonly HashSet<string> PermissionKeys = new()
    {
        "filesystem", "network", "env",
    };

    private static readonly HashSet<string> LimitKeys = new()
    {
        "memoryMB", "cpuMillis", "timeoutMs", "maxInflight",
    };

    private static readonly HashSet<string> HealthKeys = new()
    {
        "method", "intervalMs",
    };

    private static readonly HashSet<string> SignatureKeys = new()
    {
        "algorithm", "keyId",
    };

    public static PluginManifest ParseManifest(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            throw PraxoException.Plugin("plugin: manifest is empty");
        }
        JsonObject root;
        try
        {
            using var document = JsonDocument.Parse(raw);
            root = JsonNode.Parse(document.RootElement.GetRawText()) as JsonObject
                ?? throw PraxoException.Plugin("plugin: manifest must be an object");
        }
        catch (JsonException ex)
        {
            throw PraxoException.Plugin($"plugin: manifest: {ex.Message}");
        }
        CheckKeys(root, TopKeys, "manifest");
        var schemaVersion = AsInt(Json.Get(root, "schemaVersion"), "schemaVersion");
        if (schemaVersion != 1)
        {
            throw PraxoException.Plugin($"plugin: manifest: schemaVersion = {schemaVersion}, want 1");
        }
        var id = AsString(Json.Get(root, "id"), "id");
        if (!ReverseDns.IsMatch(id))
        {
            throw PraxoException.Plugin($"plugin: manifest: id {id} is not reverse-DNS");
        }
        var version = AsString(Json.Get(root, "version"), "version");
        if (!Semver.IsMatch(version))
        {
            throw PraxoException.Plugin($"plugin: manifest: version {version} is not semver");
        }
        var kind = AsString(Json.Get(root, "kind"), "kind");
        if (!Kinds.Contains(kind))
        {
            throw PraxoException.Plugin($"plugin: manifest: kind {kind} is not a known contract");
        }
        var protocol = AsString(Json.Get(root, "protocol"), "protocol");
        if (protocol != "jsonrpc-2")
        {
            throw PraxoException.Plugin($"plugin: manifest: protocol = {protocol}, want jsonrpc-2");
        }
        var entrypoint = AsObject(Json.Get(root, "entrypoint"), "entrypoint");
        CheckKeys(entrypoint, EntrypointKeys, "entrypoint");
        var entryType = AsString(Json.Get(entrypoint, "type"), "entrypoint.type");
        var required = entryType switch
        {
            "process" => "command",
            "wasm" => "module",
            "container" => "image",
            _ => throw PraxoException.Plugin($"plugin: manifest: unknown entrypoint type {entryType}"),
        };
        if (!TextPresent(Json.Get(entrypoint, required)))
        {
            throw PraxoException.Plugin($"plugin: manifest: {entryType} entrypoint requires {required}");
        }
        var isolation = AsString(Json.Get(root, "isolation"), "isolation");
        if (isolation != entryType)
        {
            throw PraxoException.Plugin($"plugin: manifest: isolation {isolation} does not match entrypoint {entryType}");
        }
        var permissions = AsObject(Json.Get(root, "permissions"), "permissions");
        CheckKeys(permissions, PermissionKeys, "permissions");
        var limits = AsObject(Json.Get(root, "limits"), "limits");
        CheckKeys(limits, LimitKeys, "limits");
        foreach (var pair in limits)
        {
            if (AsInt(pair.Value, $"limits.{pair.Key}") < 0)
            {
                throw PraxoException.Plugin("plugin: manifest: limits must not be negative");
            }
        }
        var health = AsObject(Json.Get(root, "health"), "health");
        CheckKeys(health, HealthKeys, "health");
        var signature = Json.Get(root, "signature");
        JsonObject? signatureObject = null;
        if (signature != null)
        {
            signatureObject = AsObject(signature, "signature");
            CheckKeys(signatureObject, SignatureKeys, "signature");
            if (!TextPresent(Json.Get(signatureObject, "algorithm"))
                || !TextPresent(Json.Get(signatureObject, "keyId")))
            {
                throw PraxoException.Plugin("plugin: manifest: signature requires algorithm and keyId");
            }
        }
        var capabilities = new List<string>();
        if (Json.Get(root, "capabilities") is JsonArray items)
        {
            foreach (var item in items)
            {
                capabilities.Add(AsString(item, "capabilities"));
            }
        }
        else if (Json.Get(root, "capabilities") != null)
        {
            throw PraxoException.Plugin("plugin: manifest: capabilities must be an array");
        }
        if (capabilities.Any(string.IsNullOrEmpty))
        {
            throw PraxoException.Plugin("plugin: manifest: capability must not be empty");
        }
        if (capabilities.Count != capabilities.Distinct(StringComparer.Ordinal).Count())
        {
            throw PraxoException.Plugin("plugin: manifest: duplicate capability");
        }
        var sbom = Json.GetString(root, "sbom") ?? "";
        return new PluginManifest
        {
            SchemaVersion = schemaVersion,
            Id = id,
            Version = version,
            Kind = kind,
            Entrypoint = entrypoint,
            Protocol = protocol,
            Capabilities = capabilities,
            Permissions = permissions,
            Limits = limits,
            Isolation = isolation,
            Health = health,
            Signature = signatureObject,
            Sbom = sbom,
        };
    }

    public static void ValidateTrust(PluginManifest manifest, string profile)
    {
        if (profile == "unsigned")
        {
            return;
        }
        if (profile != "signed")
        {
            throw PraxoException.Plugin($"plugin: manifest: unknown trust profile {profile}");
        }
        if (manifest.Signature == null)
        {
            throw PraxoException.Plugin("plugin: manifest: signed trust profile requires a signature");
        }
        if (string.IsNullOrEmpty(manifest.Sbom))
        {
            throw PraxoException.Plugin("plugin: manifest: signed trust profile requires an sbom");
        }
    }

    private static void CheckKeys(JsonObject obj, HashSet<string> allowed, string where)
    {
        foreach (var pair in obj)
        {
            if (!allowed.Contains(pair.Key))
            {
                throw PraxoException.Plugin($"plugin: manifest: unknown field {pair.Key} in {where}");
            }
        }
    }

    private static JsonObject AsObject(JsonNode? node, string where)
        => node switch
        {
            null => new JsonObject(),
            JsonObject obj => obj,
            _ => throw PraxoException.Plugin($"plugin: manifest: {where} must be an object"),
        };

    private static string AsString(JsonNode? node, string where)
    {
        if (node is JsonValue value && value.TryGetValue<string>(out var text))
        {
            return text;
        }
        throw PraxoException.Plugin($"plugin: manifest: {where} must be a string");
    }

    private static int AsInt(JsonNode? node, string where)
    {
        if (node is JsonValue value && value.TryGetValue<int>(out var number))
        {
            return number;
        }
        throw PraxoException.Plugin($"plugin: manifest: {where} must be an integer");
    }

    private static bool TextPresent(JsonNode? node)
        => node is JsonValue value && value.TryGetValue<string>(out var text) && text.Length > 0;
}
