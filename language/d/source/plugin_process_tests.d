module plugin_process_tests;

import core.time : Duration;
import std.stdio : writeln;
import praxo.plugin_process;

void main() {
    string python = "C:\\Python314\\python.exe";
    version (Posix)
        python = "python3";
    auto host = new ProcessHost(ProcessConfig(
        "com.example.echo",
        python,
        ["tests/fixtures/process_plugin.py"],
        "",
        Duration.zero,
        Duration.zero,
    ));
    host.start();
    scope (exit) host.stop();
    auto response = host.invoke("tool.provider", "echo", "{\"text\":\"hi\"}");
    assert(cast(string) response == "{\"text\":\"hi\"}");
    writeln("d plugin process tests passed");
}
