package io.axisvela.praxo.middleware;

public record RunState(String runId, Object session, String prompt) {
}
