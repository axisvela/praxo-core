package io.axisvela.praxo.context;

import io.axisvela.praxo.model.Message;

import java.util.List;

public interface ContextCompactor {
    List<Message> compact(List<Message> messages, ContextBudget budget)
            throws Exception;
}
