package com.axisvela.praxo.stream;

import java.util.List;

public final class Streams {
    public static final String VALUES = "values";
    public static final String UPDATES = "updates";
    public static final String MESSAGES = "messages";
    public static final String TASKS = "tasks";
    public static final String DEBUG = "debug";
    public static final String CHECKPOINT = "checkpoint";

    public static final List<String> KINDS = List.of(
            VALUES, UPDATES, MESSAGES, TASKS, DEBUG, CHECKPOINT);

    private Streams() {
    }

    public record StreamPart(
            String runId,
            String sessionId,
            String kind,
            int step,
            Object data,
            String at) {
    }
}
