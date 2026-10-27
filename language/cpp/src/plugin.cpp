#include "praxo/plugin.hpp"

#include <cmath>
#include <regex>
#include <set>

#include "praxo/errors.hpp"

namespace praxo {

namespace {

const std::set<std::string> kTopKeys = {
    "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
    "capabilities", "permissions", "limits", "isolation", "health",
    "signature", "sbom",
};
const std::set<std::string> kEntrypointKeys = {
    "type", "command", "module", "image", "args", "dir",
};
const std::set<std::string> kPermissionKeys = {"filesystem", "network", "env"};
const std::set<std::string> kLimitKeys = {
    "memoryMB", "cpuMillis", "timeoutMs", "maxInflight",
};
const std::set<std::string> kHealthKeys = {"method", "intervalMs"};
const std::set<std::string> kSignatureKeys = {"algorithm", "keyId"};
const std::set<std::string> kKinds = {
    "tool.provider.v1", "model.provider.v1", "policy.provider.v1",
    "memory.provider.v1", "sandbox.provider.v1",
};

void check_keys(const Json& value, const std::set<std::string>& allowed,
                const std::string& where) {
    for (const auto& [key, ignored] : value.as_object()) {
        (void)ignored;
        if (allowed.find(key) == allowed.end()) {
            throw PraxoError("PLUGIN_INVALID",
                             "plugin: manifest: unknown field " + key + " in " + where);
        }
    }
}

Json as_object(const Json& value, const std::string& where) {
    if (value.is_null()) return Json::object();
    if (!value.is_object()) {
        throw PraxoError("PLUGIN_INVALID",
                         "plugin: manifest: " + where + " must be an object");
    }
    return value;
}

std::string as_string(const Json& value, const std::string& where) {
    if (!value.is_string()) {
        throw PraxoError("PLUGIN_INVALID",
                         "plugin: manifest: " + where + " must be a string");
    }
    return value.as_string();
}

int as_int(const Json& value, const std::string& where) {
    if (!value.is_number() || std::floor(value.as_number()) != value.as_number()) {
        throw PraxoError("PLUGIN_INVALID",
                         "plugin: manifest: " + where + " must be an integer");
    }
    return static_cast<int>(value.as_number());
}

bool text_present(const Json& value) {
    return value.is_string() && !value.as_string().empty();
}

}  // namespace

PluginManifest parse_manifest(const std::string& raw) {
    if (raw.find_first_not_of(" \t\r\n") == std::string::npos) {
        throw PraxoError("PLUGIN_INVALID", "plugin: manifest is empty");
    }
    Json root;
    try {
        root = Json::parse(raw);
    } catch (const std::exception& error) {
        throw PraxoError("PLUGIN_INVALID", std::string("plugin: manifest: ") + error.what());
    }
    if (!root.is_object()) {
        throw PraxoError("PLUGIN_INVALID", "plugin: manifest must be an object");
    }
    check_keys(root, kTopKeys, "manifest");
    int schema_version = as_int(root.at("schemaVersion"), "schemaVersion");
    if (schema_version != 1) {
        throw PraxoError("PLUGIN_INVALID",
                         "plugin: manifest: schemaVersion = " +
                             std::to_string(schema_version) + ", want 1");
    }
    std::string id = as_string(root.at("id"), "id");
    if (!std::regex_match(id, std::regex(
            R"(^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$)"))) {
        throw PraxoError("PLUGIN_INVALID", "plugin: manifest: id " + id + " is not reverse-DNS");
    }
    std::string version = as_string(root.at("version"), "version");
    if (!std::regex_match(version, std::regex(
            R"(^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$)"))) {
        throw PraxoError("PLUGIN_INVALID", "plugin: manifest: version " + version + " is not semver");
    }
    std::string kind = as_string(root.at("kind"), "kind");
    if (kKinds.find(kind) == kKinds.end()) {
        throw PraxoError("PLUGIN_INVALID",
                         "plugin: manifest: kind " + kind + " is not a known contract");
    }
    std::string protocol = as_string(root.at("protocol"), "protocol");
    if (protocol != "jsonrpc-2") {
        throw PraxoError("PLUGIN_INVALID",
                         "plugin: manifest: protocol = " + protocol + ", want jsonrpc-2");
    }
    Json entrypoint = as_object(root.at("entrypoint"), "entrypoint");
    check_keys(entrypoint, kEntrypointKeys, "entrypoint");
    std::string entry_type = as_string(entrypoint.at("type"), "entrypoint.type");
    std::string required;
    if (entry_type == "process") required = "command";
    else if (entry_type == "wasm") required = "module";
    else if (entry_type == "container") required = "image";
    else throw PraxoError("PLUGIN_INVALID",
                          "plugin: manifest: unknown entrypoint type " + entry_type);
    if (!text_present(entrypoint.at(required))) {
        throw PraxoError("PLUGIN_INVALID",
                         "plugin: manifest: " + entry_type + " entrypoint requires " + required);
    }
    std::string isolation = as_string(root.at("isolation"), "isolation");
    if (isolation != entry_type) {
        throw PraxoError("PLUGIN_INVALID",
                         "plugin: manifest: isolation " + isolation +
                             " does not match entrypoint " + entry_type);
    }
    Json permissions = as_object(root.at("permissions"), "permissions");
    check_keys(permissions, kPermissionKeys, "permissions");
    Json limits = as_object(root.at("limits"), "limits");
    check_keys(limits, kLimitKeys, "limits");
    for (const auto& [key, value] : limits.as_object()) {
        if (as_int(value, "limits." + key) < 0) {
            throw PraxoError("PLUGIN_INVALID", "plugin: manifest: limits must not be negative");
        }
    }
    Json health = as_object(root.at("health"), "health");
    check_keys(health, kHealthKeys, "health");
    if (root.contains("signature")) {
        Json signature = as_object(root.at("signature"), "signature");
        check_keys(signature, kSignatureKeys, "signature");
        if (!text_present(signature.at("algorithm")) || !text_present(signature.at("keyId"))) {
            throw PraxoError("PLUGIN_INVALID",
                             "plugin: manifest: signature requires algorithm and keyId");
        }
    }
    std::vector<std::string> capabilities;
    if (root.contains("capabilities")) {
        if (!root.at("capabilities").is_array()) {
            throw PraxoError("PLUGIN_INVALID", "plugin: manifest: capabilities must be an array");
        }
        std::set<std::string> seen;
        for (const auto& item : root.at("capabilities").as_array()) {
            std::string capability = as_string(item, "capabilities");
            if (capability.empty()) {
                throw PraxoError("PLUGIN_INVALID", "plugin: manifest: capability must not be empty");
            }
            if (!seen.insert(capability).second) {
                throw PraxoError("PLUGIN_INVALID", "plugin: manifest: duplicate capability");
            }
            capabilities.push_back(capability);
        }
    }
    return {schema_version, id, version, kind, entrypoint, protocol,
            capabilities, permissions, limits, isolation, health};
}

}  // namespace praxo
