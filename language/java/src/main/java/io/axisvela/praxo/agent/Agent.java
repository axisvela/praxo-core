package io.axisvela.praxo.agent;

import io.axisvela.praxo.PraxoException;
import io.axisvela.praxo.context.ContextBudget;
import io.axisvela.praxo.context.Contexts;
import io.axisvela.praxo.event.Event;
import io.axisvela.praxo.middleware.CallLimitMiddleware;
import io.axisvela.praxo.middleware.FallbackModel;
import io.axisvela.praxo.middleware.Middleware;
import io.axisvela.praxo.middleware.MiddlewareToolCall;
import io.axisvela.praxo.middleware.ModelCall;
import io.axisvela.praxo.middleware.PiiMiddleware;
import io.axisvela.praxo.middleware.RunState;
import io.axisvela.praxo.middleware.StructuredOutput;
import io.axisvela.praxo.middleware.ToolResult;
import io.axisvela.praxo.middleware.ToolSelectionMiddleware;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Model;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;
import io.axisvela.praxo.model.StreamingModel;
import io.axisvela.praxo.model.ToolCall;
import io.axisvela.praxo.model.ToolSpec;
import io.axisvela.praxo.model.Usage;
import io.axisvela.praxo.policy.Action;
import io.axisvela.praxo.policy.Decision;
import io.axisvela.praxo.tool.Tool;
import io.axisvela.praxo.util.Json;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

public final class Agent {
    private final AgentOptions options;
    private final String systemPrompt;
    private final List<Middleware> middleware;
    private final List<Middleware.ModelMiddleware> modelMiddleware;

    public Agent(AgentOptions options) {
        this.options = options;
        String memory = Contexts.loadAgentsMd(options.memoryFiles);
        this.systemPrompt = memory.isEmpty()
                ? options.systemPrompt
                : (options.systemPrompt + "\n\n" + memory).trim();
        List<Middleware> items = new ArrayList<>(options.middleware);
        if (options.structuredOutput != null) {
            items.add(options.structuredOutput);
        }
        if (options.toolSelector != null) {
            items.add(new ToolSelectionMiddleware(options.toolSelector));
        }
        if (options.piiRedactor != null) {
            items.add(new PiiMiddleware(options.piiRedactor));
        }
        if (options.modelCallLimit > 0 || options.toolCallLimit > 0) {
            items.add(new CallLimitMiddleware(
                    options.modelCallLimit, options.toolCallLimit));
        }
        this.middleware = Middleware.merge(items);
        List<Middleware.ModelMiddleware> models =
                new ArrayList<>(options.modelMiddleware);
        if (options.fallbackModel != null) {
            models.add(FallbackModel.fallback(options.fallbackModel));
        }
        this.modelMiddleware = models;
    }

    public Result run(Session session, String prompt) throws Exception {
        Model model = options.model;
        if (model == null) {
            throw new IllegalArgumentException("agent: model is required");
        }
        int maxSteps = options.maxSteps > 0 ? options.maxSteps : 8;
        String runId = "run-" + System.nanoTime();
        List<Message> messages = new ArrayList<>(session.messages);
        if (!systemPrompt.isEmpty()) {
            messages.add(0, Message.of(Message.SYSTEM, systemPrompt));
        }
        messages.add(Message.of(Message.USER, prompt));
        Usage usage = Usage.zero();

        beforeRun(new RunState(runId, session, prompt));
        emit(new Event("run.started", session.id, runId, null, null));
        boolean afterRunInvoked = false;
        ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
        try {
            for (int step = 1; step <= maxSteps; step++) {
                authorize(Action.of("model.generate", session.id));
                messages = new ArrayList<>(compact(messages));
                Request request = new Request(
                        null, messages, toolSpecs(), options.toolChoice,
                        options.responseFormat, null, 0);
                ModelCall call = new ModelCall(runId, session.id, request);
                beforeModel(call);
                Response response;
                if (call.skip) {
                    if (call.response == null) {
                        throw new IllegalStateException(
                                "agent: model middleware skipped without a response");
                    }
                    response = call.response;
                } else {
                    response = generate(call.request, executor);
                }
                afterModel(call, response);
                usage = usage.plus(response.usage());
                if (options.maxTokens > 0
                        && usage.inputTokens() + usage.outputTokens() > options.maxTokens) {
                    throw PraxoException.maxTokens();
                }
                messages.add(response.message());
                if (response.message().toolCalls().isEmpty()) {
                    Result result = new Result(
                            runId, response.message().content(), step, usage);
                    afterRunInvoked = true;
                    afterRun(result, null);
                    emit(new Event("run.completed", session.id, runId, null, null));
                    return result;
                }
                for (ToolCall toolCall : response.message().toolCalls()) {
                    messages.add(invokeTool(
                            toolCall, runId, session.id, executor));
                }
            }
            throw PraxoException.maxSteps();
        } catch (Exception error) {
            if (!afterRunInvoked) {
                try {
                    afterRun(null, error);
                } catch (Exception ignored) {
                    // preserve the original run error
                }
            }
            try {
                Map<String, Object> data = new LinkedHashMap<>();
                data.put("error", error.getMessage());
                emit(new Event("run.failed", session.id, runId, data, null));
            } catch (Exception ignored) {
                // event sinks must not mask the run error
            }
            throw error;
        } finally {
            executor.close();
        }
    }

    private <T> T runCall(ExecutorService executor, Callable<T> task)
            throws Exception {
        CancellationToken token = options.cancellation;
        if (token != null && token.isCancelled()) {
            throw PraxoException.aborted();
        }
        Future<T> future = executor.submit(task);
        try {
            while (true) {
                try {
                    return future.get(10, TimeUnit.MILLISECONDS);
                } catch (TimeoutException ignored) {
                    if (token != null && token.isCancelled()) {
                        future.cancel(true);
                        throw PraxoException.aborted();
                    }
                }
            }
        } catch (InterruptedException error) {
            future.cancel(true);
            Thread.currentThread().interrupt();
            throw PraxoException.aborted();
        } catch (ExecutionException error) {
            Throwable cause = error.getCause();
            if (cause instanceof Exception exception) {
                throw exception;
            }
            if (cause instanceof Error fatal) {
                throw fatal;
            }
            throw new RuntimeException(cause);
        }
    }

    private List<Message> compact(List<Message> messages) throws Exception {
        ContextBudget budget = options.context;
        if (budget == null || budget.maxTokens() <= 0) {
            return messages;
        }
        List<Message> current = messages;
        if (options.compactor != null
                && Contexts.estimateTokens(current) > budget.maxTokens()) {
            current = options.compactor.compact(current, budget);
        }
        ContextBudget.Result result = budget.compact(current);
        if (!result.ok()) {
            throw PraxoException.contextBudget();
        }
        return result.messages();
    }

    private List<ToolSpec> toolSpecs() {
        if (options.tools == null) {
            return List.of();
        }
        List<ToolSpec> specs = options.tools.specs();
        if (options.allowedTools.isEmpty()) {
            return specs;
        }
        Set<String> allowed = Set.copyOf(options.allowedTools);
        List<ToolSpec> out = new ArrayList<>();
        for (ToolSpec spec : specs) {
            if (allowed.contains(spec.name())) {
                out.add(spec);
            }
        }
        return out;
    }

    private boolean toolAllowed(String name) {
        return options.allowedTools.isEmpty()
                || options.allowedTools.contains(name);
    }

    private Response generate(Request request, ExecutorService executor)
            throws Exception {
        Middleware.ModelHandler base = req -> {
            if (options.onDelta != null
                    && options.model instanceof StreamingModel streaming) {
                return streaming.generateStream(req, options.onDelta);
            }
            return options.model.generate(req);
        };
        Middleware.ModelHandler handler = base;
        for (int index = modelMiddleware.size() - 1; index >= 0; index--) {
            handler = modelMiddleware.get(index).apply(handler);
        }
        Middleware.ModelHandler finalHandler = handler;
        return runCall(executor, () -> finalHandler.handle(request));
    }

    private static Map<String, Object> copyArguments(Map<String, Object> arguments) {
        return Json.asObject(Json.parse(Json.stringify(arguments)));
    }

    private Message invokeTool(
            ToolCall call, String runId, String sessionId,
            ExecutorService executor) throws Exception {
        String originalName = call.name();
        Map<String, Object> originalArguments = copyArguments(call.arguments());
        if (!toolAllowed(originalName)) {
            throw new IllegalArgumentException(
                    "agent: tool " + originalName + " is not allowed");
        }
        authorize(new Action("tool.invoke", sessionId, originalName,
                copyArguments(originalArguments)));
        if (options.tools == null) {
            throw PraxoException.toolNotFound(
                    "tool " + originalName + " is not registered");
        }
        MiddlewareToolCall toolCall = new MiddlewareToolCall(
                runId, sessionId, call);
        beforeTool(toolCall);
        ToolCall active = toolCall.call;
        Object value;
        Throwable error;
        if (toolCall.skip) {
            value = toolCall.result;
            error = toolCall.error;
        } else {
            if (!toolAllowed(active.name())) {
                throw new IllegalArgumentException(
                        "agent: tool " + active.name() + " is not allowed");
            }
            if (!active.name().equals(originalName)
                    || !active.arguments().equals(originalArguments)) {
                authorize(new Action("tool.invoke", sessionId, active.name(),
                        copyArguments(active.arguments())));
            }
            Tool tool = options.tools.get(active.name());
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("name", active.name());
            data.put("arguments", copyArguments(active.arguments()));
            emit(new Event("tool.call", sessionId, runId, data, null));
            try {
                value = runCall(executor,
                        () -> tool.invoke(copyArguments(active.arguments())));
                error = null;
            } catch (Exception caught) {
                value = null;
                error = caught;
            }
        }
        ToolResult result = new ToolResult(value, error);
        afterTool(toolCall, result);
        if (result.error != null) {
            if (result.error instanceof RuntimeException runtime) {
                throw runtime;
            }
            throw new RuntimeException(result.error);
        }
        String content = Json.stringify(result.value);
        byte[] raw = content.getBytes(StandardCharsets.UTF_8);
        if (options.offloader != null
                && options.offloadThresholdBytes > 0
                && raw.length > options.offloadThresholdBytes) {
            String reference = options.offloader.offload(
                    active.name(), active.id(), raw);
            if (reference == null || reference.isEmpty()) {
                throw new IllegalStateException(
                        "agent: offloader returned an empty placeholder");
            }
            content = reference;
        }
        return Message.tool(content, active.id());
    }

    private void beforeRun(RunState state) throws Exception {
        for (Middleware item : middleware) {
            item.beforeRun(state);
        }
    }

    private void beforeModel(ModelCall call) throws Exception {
        for (Middleware item : middleware) {
            item.beforeModel(call);
            if (call.skip) {
                break;
            }
        }
    }

    private void afterModel(ModelCall call, Response response) throws Exception {
        for (Middleware item : middleware) {
            item.afterModel(call, response);
        }
    }

    private void beforeTool(MiddlewareToolCall call) throws Exception {
        for (Middleware item : middleware) {
            item.beforeTool(call);
            if (call.skip) {
                break;
            }
        }
    }

    private void afterTool(MiddlewareToolCall call, ToolResult result)
            throws Exception {
        for (Middleware item : middleware) {
            item.afterTool(call, result);
        }
    }

    private void afterRun(Result result, Throwable error) throws Exception {
        for (Middleware item : middleware) {
            item.afterRun(result, error);
        }
    }

    private void authorize(Action action) throws Exception {
        if (options.policy == null) {
            return;
        }
        Decision decision = options.policy.authorize(action);
        if (!decision.allowed()) {
            throw new PraxoException(
                    "AGENT_POLICY_DENIED",
                    "agent: " + action.kind() + " denied: "
                            + (decision.reason() == null ? "" : decision.reason()));
        }
    }

    private void emit(Event event) throws Exception {
        if (options.events == null) {
            return;
        }
        options.events.emit(event.at() == null
                ? new Event(event.type(), event.sessionId(), event.runId(),
                        event.data(), Instant.now().toString())
                : event);
    }
}
