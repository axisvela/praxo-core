package com.axisvela.praxo.context;

import com.axisvela.praxo.model.Message;

import java.util.List;

public interface ContextCompactor {
    List<Message> compact(List<Message> messages, ContextBudget budget)
            throws Exception;
}
