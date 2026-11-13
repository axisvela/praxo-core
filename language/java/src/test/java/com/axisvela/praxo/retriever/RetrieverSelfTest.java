package com.axisvela.praxo.retriever;

import java.util.List;
import java.util.Map;

public final class RetrieverSelfTest {
    private RetrieverSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        Retriever retriever = (query, limit) -> List.of(
                new Document(
                        "doc-1",
                        query + ":" + limit,
                        Map.of("source", "test"),
                        0.5));
        List<Document> documents = retriever.retrieve("hello", 3);
        check(documents.size() == 1, "document count");
        Document document = documents.get(0);
        check(document.id().equals("doc-1"), "document id");
        check(document.content().equals("hello:3"), "document content");
        check(document.metadata().get("source").equals("test"), "metadata");
        check(document.score() == 0.5, "score");
        System.out.println("retriever ok");
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
