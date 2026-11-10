package com.axisvela.praxo.adapters;

import java.nio.file.Path;
import java.util.List;
import java.util.Map;

public record McpServerConfig(
        List<String> command,
        Map<String, String> env,
        Path cwd) {
    public McpServerConfig {
        command = List.copyOf(command);
        env = env == null ? Map.of() : Map.copyOf(env);
    }

    public static McpServerConfig of(String... command) {
        return new McpServerConfig(List.of(command), Map.of(), null);
    }

    public static McpServerConfig of(List<String> command) {
        return new McpServerConfig(command, Map.of(), null);
    }
}
