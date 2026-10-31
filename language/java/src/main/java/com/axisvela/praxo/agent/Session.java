package com.axisvela.praxo.agent;

import com.axisvela.praxo.model.Message;

import java.util.ArrayList;
import java.util.List;

public final class Session {
    public final String id;
    public String tenantId = "default";
    public String workspaceId = "";
    public List<Message> messages = new ArrayList<>();

    public Session(String id) {
        this.id = id;
    }
}
