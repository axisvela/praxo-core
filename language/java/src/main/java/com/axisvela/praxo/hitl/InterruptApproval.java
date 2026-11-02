package com.axisvela.praxo.hitl;

@FunctionalInterface
public interface InterruptApproval {
    boolean approve(Interrupt interrupt) throws Exception;
}
