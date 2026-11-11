package com.axisvela.praxo.adapters;

import java.util.Map;

public record GeminiConfig(
        String baseUrl,
        String apiKey,
        String model,
        int maxOutputTokens,
        long timeoutSeconds,
        Map<String, String> headers) {

    public GeminiConfig {
        baseUrl = baseUrl == null || baseUrl.isEmpty()
                ? "https://generativelanguage.googleapis.com" : baseUrl;
        timeoutSeconds = timeoutSeconds <= 0 ? 60 : timeoutSeconds;
        headers = headers == null ? Map.of() : Map.copyOf(headers);
    }

    public static GeminiConfig of(String apiKey, String model) {
        return new GeminiConfig(
                "https://generativelanguage.googleapis.com",
                apiKey, model, 0, 60, Map.of());
    }
}
