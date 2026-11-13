package com.axisvela.praxo.agent.delegation;

public interface SubagentRunner {
    SubagentResult run(SubagentRequest request) throws Exception;
}
