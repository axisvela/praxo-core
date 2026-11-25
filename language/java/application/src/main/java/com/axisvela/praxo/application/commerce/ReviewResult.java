package com.axisvela.praxo.application.commerce;

import java.util.LinkedHashMap;
import java.util.Map;

public record ReviewResult(
        Map<String, Object> report,
        int reads,
        int drafts,
        int reviews,
        int checkouts) {

    public Map<String, Object> toMap() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("report", report);
        Map<String, Object> agent = new LinkedHashMap<>();
        agent.put("reads", reads);
        agent.put("drafts", drafts);
        agent.put("reviews", reviews);
        agent.put("checkouts", checkouts);
        out.put("agent", agent);
        return out;
    }
}
