package starter;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.middleware.Middleware;
import com.axisvela.praxo.middleware.MiddlewareToolCall;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.policy.Hook;
import com.axisvela.praxo.tool.Registry;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class GovernedCompatTest {
    private record Governed(AgentOptions options, App.RecordTool tool) {
    }

    private static Governed governedOptions(Hook hook, List<String> allowed) {
        if (hook == null) {
            throw new IllegalArgumentException("governed: mandatory policy is missing");
        }
        if (allowed == null || allowed.isEmpty()) {
            throw new IllegalArgumentException("governed: explicit tool scope is required");
        }
        Registry tools = new Registry();
        App.RecordTool tool = new App.RecordTool();
        tools.register(tool);
        AgentOptions options = new AgentOptions(new App.FixtureModel("public"));
        options.tools = tools;
        options.maxSteps = 3;
        options.policy = hook;
        options.allowedTools = new ArrayList<>(allowed);
        return new Governed(options, tool);
    }

    private static Hook publicOnly(List<String> checked) {
        return (Action action) -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("model generation");
            }
            if ("tool.invoke".equals(action.kind())) {
                Object target = action.arguments() == null
                        ? null
                        : action.arguments().get("target");
                checked.add(String.valueOf(target));
                return "public".equals(target)
                        ? Decision.allow("public target")
                        : Decision.deny("only the public target is permitted");
            }
            return Decision.deny("unsupported action");
        };
    }

    @Test
    void missingPolicyIsRejected() {
        assertThrows(IllegalArgumentException.class,
                () -> governedOptions(null, List.of("record")));
    }

    @Test
    void emptyToolScopeIsRejected() {
        assertThrows(IllegalArgumentException.class,
                () -> governedOptions(publicOnly(new ArrayList<>()), List.of()));
    }

    @Test
    void finalArgumentsAreReauthorized() throws Exception {
        List<String> checked = new ArrayList<>();
        Governed governed = governedOptions(publicOnly(checked), List.of("record"));
        governed.options().middleware = new ArrayList<>(List.of(new Middleware() {
            @Override
            public void beforeTool(MiddlewareToolCall call) {
                call.call = new ToolCall(
                        call.call.id(), call.call.name(), Map.of("target", "private"));
            }
        }));
        Agent agent = new Agent(governed.options());
        PraxoException error = assertThrows(PraxoException.class,
                () -> agent.run(new Session("compat-final-args"), "record"));
        assertEquals("AGENT_POLICY_DENIED", error.code);
        assertEquals(0, governed.tool().calls());
        assertEquals(List.of("public", "private"), checked);
    }

    @Test
    void policyErrorFailsClosed() throws Exception {
        Hook hook = action -> {
            if ("tool.invoke".equals(action.kind())) {
                throw new Exception("policy service unavailable");
            }
            return Decision.allow("model generation");
        };
        Governed governed = governedOptions(hook, List.of("record"));
        Agent agent = new Agent(governed.options());
        assertThrows(Exception.class,
                () -> agent.run(new Session("compat-policy-error"), "record"));
        assertEquals(0, governed.tool().calls());
    }
}
