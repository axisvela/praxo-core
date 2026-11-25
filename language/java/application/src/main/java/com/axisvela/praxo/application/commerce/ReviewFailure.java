package com.axisvela.praxo.application.commerce;

import java.util.LinkedHashMap;
import java.util.Map;

public final class ReviewFailure extends RuntimeException {
    public final String code;
    public final int reads;
    public final int drafts;
    public final int reviews;
    public final int checkouts;

    public ReviewFailure(
            String code,
            String message,
            int reads,
            int drafts,
            int reviews,
            int checkouts) {
        super(message);
        this.code = code;
        this.reads = reads;
        this.drafts = drafts;
        this.reviews = reviews;
        this.checkouts = checkouts;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("error", code);
        out.put("message", getMessage());
        Map<String, Object> agent = new LinkedHashMap<>();
        agent.put("reads", reads);
        agent.put("drafts", drafts);
        agent.put("reviews", reviews);
        agent.put("checkouts", checkouts);
        out.put("agent", agent);
        return out;
    }
}
