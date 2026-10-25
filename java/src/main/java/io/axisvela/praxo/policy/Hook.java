package io.axisvela.praxo.policy;

public interface Hook {
    Decision authorize(Action action) throws Exception;
}
