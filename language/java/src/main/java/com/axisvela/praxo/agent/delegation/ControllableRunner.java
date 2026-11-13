package com.axisvela.praxo.agent.delegation;

public interface ControllableRunner extends SubagentRunner {
    void update(String taskId, String prompt) throws Exception;
}
