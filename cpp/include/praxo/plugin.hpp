#pragma once

#include <string>
#include <vector>

#include "praxo/json.hpp"

namespace praxo {

struct PluginManifest {
    int schema_version = 1;
    std::string id;
    std::string version;
    std::string kind;
    Json entrypoint = Json::object();
    std::string protocol;
    std::vector<std::string> capabilities;
    Json permissions = Json::object();
    Json limits = Json::object();
    std::string isolation;
    Json health = Json::object();
};

PluginManifest parse_manifest(const std::string& raw);

}  // namespace praxo
