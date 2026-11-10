package com.axisvela.praxo.adapters;

import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.tool.Tool;

import java.util.Map;

public final class McpToolAdapter implements Tool {
    private final McpClient client;
    private final McpTool tool;

    public McpToolAdapter(McpClient client, McpTool tool) {
        this.client = client;
        this.tool = tool;
    }

    @Override
    public String name() {
        return tool.name();
    }

    @Override
    public String description() {
        return tool.description();
    }

    @Override
    public Object invoke(Map<String, Object> args) throws Exception {
        return client.callTool(tool.name(), args);
    }

    public McpTool tool() {
        return tool;
    }

    public ToolSpec spec() {
        return tool.toSpec();
    }
}
