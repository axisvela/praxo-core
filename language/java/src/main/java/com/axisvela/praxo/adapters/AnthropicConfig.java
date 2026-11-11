package com.axisvela.praxo.adapters;

import java.util.Map;

public record AnthropicConfig(
        String baseUrl,
        String apiKey,
        String model,
        String version,
        int maxTokens,
        long timeoutSeconds,
        Map<String, String> headers) {

    public AnthropicConfig {
        baseUrl = baseUrl == null || baseUrl.isEmpty()
                ? "https://api.anthropic.com" : baseUrl;
        version = version == null || version.isEmpty()
                ? "2023-06-01" : version;
        maxTokens = maxTokens <= 0 ? 1024 : maxTokens;
        timeoutSeconds = timeoutSeconds <= 0 ? 60 : timeoutSeconds;
        headers = headers == null ? Map.of() : Map.copyOf(headers);
    }

    public static AnthropicConfig of(String apiKey, String model) {
        return new AnthropicConfig(
                "https://api.anthropic.com", apiKey, model,
                "2023-06-01", 1024, 60, Map.of());
    }
}
