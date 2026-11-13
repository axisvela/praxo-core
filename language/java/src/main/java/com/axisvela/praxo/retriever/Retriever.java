package com.axisvela.praxo.retriever;

import java.util.List;

@FunctionalInterface
public interface Retriever {
    List<Document> retrieve(String query, int limit) throws Exception;
}
