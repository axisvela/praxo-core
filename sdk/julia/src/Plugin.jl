module Plugin

using ..Json

export PluginManifest, parse_manifest

struct PluginManifest
    schema_version::Int
    id::String
    version::String
    kind::String
    entrypoint::Dict{String,Any}
    protocol::String
    capabilities::Vector{String}
    permissions::Dict{String,Any}
    limits::Dict{String,Any}
    isolation::String
    health::Dict{String,Any}
end

const KINDS = [
    "tool.provider.v1", "model.provider.v1", "policy.provider.v1",
    "memory.provider.v1", "sandbox.provider.v1",
]

const TOP_KEYS = Set([
    "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
    "capabilities", "permissions", "limits", "isolation", "health",
    "signature", "sbom",
])
const ENTRYPOINT_KEYS = Set(["type", "command", "module", "image", "args", "dir"])
const PERMISSION_KEYS = Set(["filesystem", "network", "env"])
const LIMIT_KEYS = Set(["memoryMB", "cpuMillis", "timeoutMs", "maxInflight"])
const HEALTH_KEYS = Set(["method", "intervalMs"])
const SIGNATURE_KEYS = Set(["algorithm", "keyId"])

function parse_manifest(raw::AbstractString)
    isempty(strip(raw)) && error("plugin: manifest is empty")
    root = try
        Json.parse_json(raw)
    catch error_value
        error("plugin: manifest: $(error_value)")
    end
    root isa AbstractDict || error("plugin: manifest must be an object")
    check_keys(root, TOP_KEYS, "manifest")
    schema_version = as_int(get(root, "schemaVersion", nothing), "schemaVersion")
    schema_version == 1 || error("plugin: manifest: schemaVersion = $(schema_version), want 1")
    id = as_string(get(root, "id", nothing), "id")
    occursin(r"^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", id) ||
        error("plugin: manifest: id $(id) is not reverse-DNS")
    version = as_string(get(root, "version", nothing), "version")
    occursin(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$", version) ||
        error("plugin: manifest: version $(version) is not semver")
    kind = as_string(get(root, "kind", nothing), "kind")
    kind in KINDS || error("plugin: manifest: kind $(kind) is not a known contract")
    protocol = as_string(get(root, "protocol", nothing), "protocol")
    protocol == "jsonrpc-2" || error("plugin: manifest: protocol = $(protocol), want jsonrpc-2")
    entrypoint = as_object(get(root, "entrypoint", nothing), "entrypoint")
    check_keys(entrypoint, ENTRYPOINT_KEYS, "entrypoint")
    entry_type = as_string(get(entrypoint, "type", nothing), "entrypoint.type")
    required = entry_type == "process" ? "command" :
        entry_type == "wasm" ? "module" :
        entry_type == "container" ? "image" :
        error("plugin: manifest: unknown entrypoint type $(entry_type)")
    text_present(get(entrypoint, required, nothing)) ||
        error("plugin: manifest: $(entry_type) entrypoint requires $(required)")
    isolation = as_string(get(root, "isolation", nothing), "isolation")
    isolation == entry_type ||
        error("plugin: manifest: isolation $(isolation) does not match entrypoint $(entry_type)")
    permissions = as_object(get(root, "permissions", nothing), "permissions")
    check_keys(permissions, PERMISSION_KEYS, "permissions")
    limits = as_object(get(root, "limits", nothing), "limits")
    check_keys(limits, LIMIT_KEYS, "limits")
    for (key, value) in limits
        as_int(value, "limits.$(key)") < 0 &&
            error("plugin: manifest: limits must not be negative")
    end
    health = as_object(get(root, "health", nothing), "health")
    check_keys(health, HEALTH_KEYS, "health")
    signature = get(root, "signature", nothing)
    if signature !== nothing
        signature_object = as_object(signature, "signature")
        check_keys(signature_object, SIGNATURE_KEYS, "signature")
        (text_present(get(signature_object, "algorithm", nothing)) &&
            text_present(get(signature_object, "keyId", nothing))) ||
            error("plugin: manifest: signature requires algorithm and keyId")
    end
    capabilities = String[]
    raw_capabilities = get(root, "capabilities", nothing)
    if raw_capabilities !== nothing
        raw_capabilities isa AbstractVector ||
            error("plugin: manifest: capabilities must be an array")
        for item in raw_capabilities
            push!(capabilities, as_string(item, "capabilities"))
        end
    end
    "" in capabilities && error("plugin: manifest: capability must not be empty")
    length(capabilities) == length(unique(capabilities)) ||
        error("plugin: manifest: duplicate capability")
    return PluginManifest(
        schema_version,
        id,
        version,
        kind,
        Dict{String,Any}(String(k) => v for (k, v) in entrypoint),
        protocol,
        capabilities,
        Dict{String,Any}(String(k) => v for (k, v) in permissions),
        Dict{String,Any}(String(k) => v for (k, v) in limits),
        isolation,
        Dict{String,Any}(String(k) => v for (k, v) in health),
    )
end

function check_keys(value, allowed, where_name)
    for key in keys(value)
        key in allowed || error("plugin: manifest: unknown field $(key) in $(where_name)")
    end
end

function as_object(value, where_name)
    value === nothing && return Dict{String,Any}()
    value isa AbstractDict || error("plugin: manifest: $(where_name) must be an object")
    return Dict{String,Any}(String(k) => v for (k, v) in value)
end

function as_string(value, where_name)
    value isa AbstractString || error("plugin: manifest: $(where_name) must be a string")
    return String(value)
end

function as_int(value, where_name)
    value isa Integer && !(value isa Bool) ||
        error("plugin: manifest: $(where_name) must be an integer")
    return Int(value)
end

function text_present(value)
    return value isa AbstractString && !isempty(value)
end

end
