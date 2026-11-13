#pragma once

#include <functional>
#include <map>
#include <string>
#include <vector>

#include "praxo/errors.hpp"
#include "praxo/json.hpp"

namespace praxo {

struct Document {
    std::string id;
    std::string content;
    std::map<std::string, std::string> metadata;
    double score = 0.0;

    Json wire() const {
        Json out = Json::object();
        out["id"] = id;
        out["content"] = content;
        if (!metadata.empty()) {
            Json values = Json::object();
            for (const auto& [key, value] : metadata) {
                values[key] = value;
            }
            out["metadata"] = values;
        }
        if (score != 0.0) {
            out["score"] = score;
        }
        return out;
    }
};

using Retriever =
    std::function<std::vector<Document>(const std::string& query, int limit)>;

inline std::vector<Document> retrieve(const Retriever& retriever,
                                      const std::string& query, int limit) {
    if (!retriever) {
        throw PraxoError("RETRIEVER_INVALID", "retriever: retrieve is required");
    }
    if (limit < 0) {
        throw PraxoError("RETRIEVER_INVALID", "retriever: invalid limit");
    }
    return retriever(query, limit);
}

}  // namespace praxo
