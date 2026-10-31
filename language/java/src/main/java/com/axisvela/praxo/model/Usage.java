package com.axisvela.praxo.model;

public record Usage(long inputTokens, long outputTokens, long cachedTokens) {
    public static Usage zero() {
        return new Usage(0, 0, 0);
    }

    public Usage plus(Usage other) {
        return new Usage(
                inputTokens + other.inputTokens,
                outputTokens + other.outputTokens,
                cachedTokens + other.cachedTokens);
    }
}
