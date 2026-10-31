package com.axisvela.praxo.middleware;

public final class ToolResult {
    public Object value;
    public Throwable error;

    public ToolResult(Object value, Throwable error) {
        this.value = value;
        this.error = error;
    }
}
