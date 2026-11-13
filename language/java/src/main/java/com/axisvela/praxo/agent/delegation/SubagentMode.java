package com.axisvela.praxo.agent.delegation;

public enum SubagentMode {
    ISOLATED("isolated"),
    FORK("fork");

    private final String wire;

    SubagentMode(String wire) {
        this.wire = wire;
    }

    public String wire() {
        return wire;
    }
}
