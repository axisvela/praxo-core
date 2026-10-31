package com.axisvela.praxo.tool;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.model.ToolSpec;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class Registry {
    private final Map<String, Tool> tools = new LinkedHashMap<>();

    public synchronized void register(Tool tool) {
        tools.put(tool.name(), tool);
    }

    public synchronized Tool get(String name) {
        Tool tool = tools.get(name);
        if (tool == null) {
            throw PraxoException.toolNotFound("tool not found: " + name);
        }
        return tool;
    }

    public synchronized List<ToolSpec> specs() {
        List<ToolSpec> out = new ArrayList<>();
        for (Tool tool : tools.values()) {
            out.add(new ToolSpec(tool.name(), tool.description()));
        }
        out.sort(Comparator.comparing(ToolSpec::name));
        return out;
    }

    public synchronized int size() {
        return tools.size();
    }
}
