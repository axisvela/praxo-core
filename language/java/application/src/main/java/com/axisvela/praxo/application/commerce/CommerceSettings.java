package com.axisvela.praxo.application.commerce;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public final class CommerceSettings {
    private final String tenant;
    private final boolean catalogFailure;
    private final int maxIntentLength;
    private final String baseUrl;
    private final String apiKey;
    private final String model;

    public CommerceSettings(
            @Value("${praxo.commerce.tenant:acme}") String tenant,
            @Value("${praxo.commerce.catalog-failure:false}") boolean catalogFailure,
            @Value("${praxo.commerce.max-intent-length:500}") int maxIntentLength,
            @Value("${praxo.commerce.model.base-url:}") String baseUrl,
            @Value("${praxo.commerce.model.api-key:}") String apiKey,
            @Value("${praxo.commerce.model.name:}") String model) {
        this.tenant = tenant;
        this.catalogFailure = catalogFailure;
        this.maxIntentLength = maxIntentLength;
        this.baseUrl = baseUrl;
        this.apiKey = apiKey;
        this.model = model;
    }

    public String tenant() {
        return tenant;
    }

    public boolean catalogFailure() {
        return catalogFailure;
    }

    public int maxIntentLength() {
        return maxIntentLength;
    }

    public String baseUrl() {
        return baseUrl;
    }

    public String apiKey() {
        return apiKey;
    }

    public String model() {
        return model;
    }
}
