package com.axisvela.praxo.agent.delegation;

public enum SubagentStatus {
    QUEUED("queued"),
    RUNNING("running"),
    COMPLETED("completed"),
    FAILED("failed"),
    CANCELED("canceled");

    private final String wire;

    SubagentStatus(String wire) {
        this.wire = wire;
    }

    public String wire() {
        return wire;
    }

    public boolean terminal() {
        return this == COMPLETED || this == FAILED || this == CANCELED;
    }
}
