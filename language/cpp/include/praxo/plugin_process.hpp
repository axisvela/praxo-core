#pragma once

#include <stdexcept>
#include <string>
#include <utility>

extern "C" {
int px_plugin_process_start_simple(const char *plugin_id, const char *path,
                                   const char *arg, const char *token,
                                   void **handle, char *error,
                                   size_t error_size);
int px_plugin_process_invoke_simple(void *handle, const char *service,
                                    const char *method, const char *payload,
                                    char *response, size_t response_size,
                                    char *error, size_t error_size);
void px_plugin_process_stop_simple(void *handle);
}

namespace praxo {

struct ProcessPluginConfig {
    std::string plugin_id;
    std::string path;
    std::string argument;
    std::string token;
};

class ProcessPluginHost {
public:
    explicit ProcessPluginHost(ProcessPluginConfig config)
        : config_(std::move(config)) {
        if (config_.plugin_id.empty()) {
            throw std::invalid_argument("plugin: PluginID is required");
        }
        if (config_.path.empty()) {
            throw std::invalid_argument("plugin: path is required");
        }
    }

    ~ProcessPluginHost() { stop(); }

    ProcessPluginHost(const ProcessPluginHost &) = delete;
    ProcessPluginHost &operator=(const ProcessPluginHost &) = delete;

    void start() {
        if (handle_ != nullptr) {
            throw std::runtime_error("plugin: host already started");
        }
        char error[256] = {0};
        void *handle = nullptr;
        if (px_plugin_process_start_simple(
                config_.plugin_id.c_str(), config_.path.c_str(),
                config_.argument.c_str(), config_.token.c_str(), &handle,
                error, sizeof(error)) == 0 ||
            handle == nullptr) {
            throw std::runtime_error(error);
        }
        handle_ = handle;
    }

    std::string invoke(const std::string &service, const std::string &method,
                       const std::string &payload = "") {
        if (handle_ == nullptr) {
            throw std::runtime_error("plugin: host is not active");
        }
        char response[8192] = {0};
        char error[256] = {0};
        if (px_plugin_process_invoke_simple(
                handle_, service.c_str(), method.c_str(), payload.c_str(),
                response, sizeof(response), error, sizeof(error)) == 0) {
            throw std::runtime_error(error);
        }
        return response;
    }

    void stop() {
        if (handle_ != nullptr) {
            px_plugin_process_stop_simple(handle_);
            handle_ = nullptr;
        }
    }

    bool active() const { return handle_ != nullptr; }

private:
    ProcessPluginConfig config_;
    void *handle_ = nullptr;
};

} // namespace praxo
