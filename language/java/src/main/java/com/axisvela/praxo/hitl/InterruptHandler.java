package com.axisvela.praxo.hitl;

@FunctionalInterface
public interface InterruptHandler {
    InterruptDecision decide(Interrupt interrupt) throws Exception;
}
