package io.axisvela.praxo.adapters;

import java.util.Map;

public record OpenAIConfig(
        String baseUrl,
        String apiKey,
        String model,
        long timeoutSeconds,
        Map<String, String> headers) {

    public OpenAIConfig {
        headers = headers == null ? Map.of() : Map.copyOf(headers);
    }

    public static OpenAIConfig of(String baseUrl, String model) {
        return new OpenAIConfig(baseUrl, "", model, 60, Map.of());
    }
}
