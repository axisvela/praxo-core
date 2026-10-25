package io.axisvela.praxo.agent;

import io.axisvela.praxo.model.Usage;

public final class Result {
    public final String runId;
    public String output;
    public int steps;
    public Usage usage;

    public Result(String runId, String output, int steps, Usage usage) {
        this.runId = runId;
        this.output = output;
        this.steps = steps;
        this.usage = usage;
    }
}
