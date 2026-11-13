package com.axisvela.praxo.agent.delegation;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

public final class SubagentManager {
    private final SubagentRunner runner;
    private final ConcurrentHashMap<String, TaskState> tasks = new ConcurrentHashMap<>();
    private final AtomicInteger sequence = new AtomicInteger();

    public SubagentManager(SubagentRunner runner) {
        this.runner = runner;
    }

    public SubagentTask launch(SubagentRequest request) {
        if (runner == null) {
            throw new IllegalArgumentException("agent: subagent runner is required");
        }
        if (request == null || isBlank(request.parentSessionId())
                || isBlank(request.agentId())) {
            throw new IllegalArgumentException(
                    "agent: subagent parent session and agent id are required");
        }
        String id = "subagent-" + sequence.incrementAndGet();
        Instant now = Instant.now();
        SubagentTask task = new SubagentTask(
                id,
                request.parentSessionId(),
                request.agentId(),
                request.mode(),
                SubagentStatus.QUEUED,
                "",
                "",
                now,
                now);
        TaskState state = new TaskState(task);
        tasks.put(id, state);
        state.job = CompletableFuture.runAsync(() -> execute(id, request, state));
        return task;
    }

    public SubagentTask check(String taskId) {
        TaskState state = tasks.get(taskId);
        return state == null ? null : state.task;
    }

    public SubagentTask wait(String taskId) throws Exception {
        TaskState state = require(taskId);
        state.done.get();
        return state.task;
    }

    public SubagentTask wait(String taskId, Duration timeout) throws Exception {
        TaskState state = require(taskId);
        state.done.get(timeout.toMillis(), TimeUnit.MILLISECONDS);
        return state.task;
    }

    public void update(String taskId, String prompt) throws Exception {
        if (!(runner instanceof ControllableRunner controllable)) {
            throw new SubagentUpdateUnsupportedException();
        }
        TaskState state = require(taskId);
        if (state.task.status() != SubagentStatus.RUNNING) {
            throw new IllegalStateException(
                    "agent: subagent task \"" + taskId + "\" is not running");
        }
        controllable.update(taskId, prompt);
    }

    public void cancel(String taskId) {
        TaskState state = require(taskId);
        if (state.task.status().terminal()) {
            return;
        }
        state.job.cancel(true);
        tasks.computeIfPresent(taskId, (key, current) -> {
            current.task = copy(
                    current.task,
                    SubagentStatus.CANCELED,
                    "",
                    "");
            return current;
        });
        state.done.complete(null);
    }

    private void execute(String taskId, SubagentRequest request, TaskState state) {
        setTask(taskId, SubagentStatus.RUNNING, "", "");
        try {
            SubagentResult result = runner.run(request);
            setTask(taskId, SubagentStatus.COMPLETED, result.output(), "");
        } catch (Exception error) {
            setTask(
                    taskId,
                    SubagentStatus.FAILED,
                    "",
                    error.getMessage() == null ? error.toString() : error.getMessage());
        } finally {
            state.done.complete(null);
        }
    }

    private void setTask(
            String taskId,
            SubagentStatus status,
            String output,
            String error) {
        tasks.computeIfPresent(taskId, (key, state) -> {
            if (state.task.status().terminal()) {
                return state;
            }
            state.task = copy(state.task, status, output, error);
            return state;
        });
    }

    private TaskState require(String taskId) {
        TaskState state = tasks.get(taskId);
        if (state == null) {
            throw new IllegalArgumentException(
                    "agent: unknown subagent task \"" + taskId + "\"");
        }
        return state;
    }

    private static SubagentTask copy(
            SubagentTask task,
            SubagentStatus status,
            String output,
            String error) {
        return new SubagentTask(
                task.id(),
                task.parentSessionId(),
                task.agentId(),
                task.mode(),
                status,
                output,
                error,
                task.createdAt(),
                Instant.now());
    }

    private static boolean isBlank(String value) {
        return value == null || value.isEmpty();
    }

    private static final class TaskState {
        private volatile SubagentTask task;
        private final CompletableFuture<Void> done = new CompletableFuture<>();
        private volatile CompletableFuture<Void> job;

        private TaskState(SubagentTask task) {
            this.task = task;
        }
    }
}
