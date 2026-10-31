package com.axisvela.praxo.agent;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.context.ContextBudget;
import com.axisvela.praxo.middleware.CallLimitMiddleware;
import com.axisvela.praxo.middleware.MiddlewareToolCall;
import com.axisvela.praxo.middleware.ModelCall;
import com.axisvela.praxo.middleware.RunState;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;

import java.util.List;

public final class AgentGuardrailSelfTest {
    private AgentGuardrailSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        modelCallLimitFailsClosed();
        toolCallLimitFailsClosed();
        callLimitSeparatesRuns();
        contextBudgetFailsClosed();
        System.out.println("agent guardrail ok");
    }

    private static void modelCallLimitFailsClosed() {
        CallLimitMiddleware middleware = new CallLimitMiddleware(1, 0);
        middleware.beforeRun(new RunState("run-model", null, ""));
        ModelCall call = new ModelCall(
                "run-model", "s1", Request.of(List.of()));
        middleware.beforeModel(call);
        try {
            middleware.beforeModel(call);
            throw new AssertionError("expected model call limit");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_MODEL_CALL_LIMIT"), "model limit: " + error.code);
        }
    }

    private static void toolCallLimitFailsClosed() {
        CallLimitMiddleware middleware = new CallLimitMiddleware(0, 1);
        middleware.beforeRun(new RunState("run-tool", null, ""));
        MiddlewareToolCall call = new MiddlewareToolCall(
                "run-tool", "s1", new ToolCall("c1", "echo", null));
        middleware.beforeTool(call);
        try {
            middleware.beforeTool(call);
            throw new AssertionError("expected tool call limit");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_TOOL_CALL_LIMIT"), "tool limit: " + error.code);
        }
    }

    private static void callLimitSeparatesRuns() {
        CallLimitMiddleware middleware = new CallLimitMiddleware(1, 0);
        middleware.beforeRun(new RunState("a", null, ""));
        middleware.beforeRun(new RunState("b", null, ""));
        middleware.beforeModel(new ModelCall("a", "s1", Request.of(List.of())));
        middleware.beforeModel(new ModelCall("b", "s1", Request.of(List.of())));
    }

    private static void contextBudgetFailsClosed() throws Exception {
        Model model = request -> Response.of(Message.assistant("done", List.of()));
        AgentOptions options = new AgentOptions(model);
        options.systemPrompt = "x".repeat(1000);
        options.context = new ContextBudget(10, 0);
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected context budget failure");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_CONTEXT_BUDGET"),
                    "context budget: " + error.code);
        }
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
