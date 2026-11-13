package com.axisvela.praxo.agent.delegation;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;

public final class DelegationSelfTest {
    private DelegationSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        SubagentManager manager = new SubagentManager(
                request -> new SubagentResult("", "", "done", null));
        SubagentTask task = manager.launch(request());
        check("parent".equals(task.parentSessionId()), "parent session");
        check("child".equals(task.agentId()), "agent id");
        check(task.mode() == SubagentMode.FORK, "mode");
        SubagentTask completed = manager.wait(task.id(), Duration.ofSeconds(2));
        check(completed.status() == SubagentStatus.COMPLETED, "completed");
        check("done".equals(completed.output()), "output");

        SubagentManager failing = new SubagentManager(request -> {
            throw new IllegalStateException("boom");
        });
        SubagentTask failed = failing.wait(
                failing.launch(request()).id(),
                Duration.ofSeconds(2));
        check(failed.status() == SubagentStatus.FAILED, "failed");
        check(failed.error().contains("boom"), "failure detail");

        CountDownLatch release = new CountDownLatch(1);
        SubagentManager blocking = new SubagentManager(request -> {
            release.await();
            return new SubagentResult("", "", "released", null);
        });
        SubagentTask running = blocking.launch(request());
        awaitStatus(blocking, running.id(), SubagentStatus.RUNNING);
        blocking.cancel(running.id());
        SubagentTask canceled = blocking.wait(running.id(), Duration.ofSeconds(2));
        check(canceled.status() == SubagentStatus.CANCELED, "canceled");
        release.countDown();

        List<String> updates = new ArrayList<>();
        CountDownLatch updateRelease = new CountDownLatch(1);
        SubagentManager controllable = new SubagentManager(new ControllableRunner() {
            @Override
            public SubagentResult run(SubagentRequest request) throws Exception {
                updateRelease.await();
                return new SubagentResult("", "", "released", null);
            }

            @Override
            public void update(String taskId, String prompt) {
                updates.add(taskId + ":" + prompt);
            }
        });
        SubagentTask controlled = controllable.launch(request());
        awaitStatus(controllable, controlled.id(), SubagentStatus.RUNNING);
        controllable.update(controlled.id(), "steer");
        check(updates.equals(List.of(controlled.id() + ":steer")), "update");
        updateRelease.countDown();
        check(
                controllable.wait(controlled.id(), Duration.ofSeconds(2)).status()
                        == SubagentStatus.COMPLETED,
                "controlled completion");

        try {
            controllable.update("missing", "steer");
            throw new AssertionError("expected unknown task");
        } catch (IllegalArgumentException expected) {
        }
        System.out.println("delegation ok");
    }

    private static SubagentRequest request() {
        return new SubagentRequest(
                "parent",
                "child",
                "do work",
                Map.of(),
                SubagentMode.FORK,
                List.of());
    }

    private static void awaitStatus(
            SubagentManager manager,
            String taskId,
            SubagentStatus status) throws Exception {
        for (int attempt = 0; attempt < 100; attempt++) {
            SubagentTask task = manager.check(taskId);
            if (task != null && task.status() == status) {
                return;
            }
            Thread.sleep(10);
        }
        throw new AssertionError("status did not become " + status);
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
