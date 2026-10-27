package io.axisvela.praxo.middleware;

import io.axisvela.praxo.model.ToolSpec;

import java.util.List;

public interface ToolSelector {
    List<String> select(String query, List<ToolSpec> tools) throws Exception;
}
