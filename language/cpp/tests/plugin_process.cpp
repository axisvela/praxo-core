#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>

#include "praxo/plugin_process.hpp"

int main() {
    const char *configured = std::getenv("PRAXO_PYTHON");
#ifdef _WIN32
    const std::string python = configured ? configured : "python";
#else
    const std::string python = configured ? configured : "python3";
#endif
    praxo::ProcessPluginConfig config{
        "com.example.echo", python, "tests/fixtures/process_plugin.py", ""};
    praxo::ProcessPluginHost host(std::move(config));
    host.start();
    try {
        const std::string response =
            host.invoke("tool.provider", "echo", "{\"text\":\"hi\"}");
        if (response != "{\"text\":\"hi\"}") {
            throw std::runtime_error("unexpected response: " + response);
        }
        std::cout << "cpp plugin process tests passed\n";
    } catch (...) {
        host.stop();
        throw;
    }
    host.stop();
    return 0;
}
