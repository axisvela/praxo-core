package com.axisvela.praxo.retriever;

import java.util.Map;

public record Document(
        String id,
        String content,
        Map<String, String> metadata,
        double score) {

    public Document {
        metadata = metadata == null ? Map.of() : Map.copyOf(metadata);
    }
}
