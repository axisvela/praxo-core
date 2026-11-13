package identity;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.policy.Hook;
import com.axisvela.praxo.tool.FuncTool;
import com.axisvela.praxo.tool.Registry;

import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

public final class IdentityPolicyExample {
    private static final String SESSION_ID = "session-1";

    private IdentityPolicyExample() {
    }

    record Principal(String tenant, String role, boolean active) {
    }

    static final class ClaimingModel implements Model {
        private final String tenant;
        private final String role;

        ClaimingModel(String tenant, String role) {
            this.tenant = tenant;
            this.role = role;
        }

        @Override
        public Response generate(Request request) {
            Message last = request.messages().get(request.messages().size() - 1);
            if (Message.TOOL.equals(last.role())) {
                return Response.of(Message.assistant("recorded", List.of()));
            }
            return Response.of(Message.assistant("", List.of(new ToolCall(
                    "record-1", "record",
                    Map.of("tenant", tenant, "role", role)))));
        }
    }

    static Hook policy(Principal principal) {
        return action -> {
            if (principal == null) {
                return Decision.deny("trusted principal is missing");
            }
            if (!principal.active()) {
                return Decision.deny("trusted principal is inactive");
            }
            if (action.kind().equals("model.generate")) {
                return Decision.allow("principal may run the agent");
            }
            if (!action.kind().equals("tool.invoke")) {
                return Decision.deny("unsupported action");
            }
            if (!principal.role().equals("operator")) {
                return Decision.deny("role is not permitted");
            }
            Object claimed = action.arguments() == null
                    ? null
                    : action.arguments().get("tenant");
            if (!principal.tenant().equals(claimed)) {
                return Decision.deny("tenant does not match the principal");
            }
            if (!"record".equals(action.toolName())) {
                return Decision.deny("operation is not permitted");
            }
            return Decision.allow("verified operator");
        };
    }

    static Throwable runCase(Principal principal, String claimedTenant, String claimedRole)
            throws Exception {
        AtomicInteger calls = new AtomicInteger();
        Registry tools = new Registry();
        tools.register(new FuncTool("record", "Record a target.", args -> {
            calls.incrementAndGet();
            return "recorded";
        }));
        AgentOptions options = new AgentOptions(new ClaimingModel(claimedTenant, claimedRole));
        options.tools = tools;
        options.policy = policy(principal);
        options.allowedTools = List.of("record");
        options.maxSteps = 3;
        try {
            String output = new Agent(options)
                    .run(new Session(SESSION_ID), "record")
                    .output;
            if (!output.equals("recorded")) {
                throw new IllegalStateException(output);
            }
        } catch (Throwable error) {
            if (calls.get() != 0 && !(principal != null
                    && principal.active()
                    && principal.role().equals("operator"))) {
                throw new IllegalStateException("effect ran before denial", error);
            }
            return error;
        }
        if (calls.get() != 1) {
            throw new IllegalStateException("allowed case did not invoke the tool");
        }
        return null;
    }

    public static void main(String[] args) throws Exception {
        checkDenied(null, "acme", "admin");
        checkDenied(new Principal("acme", "operator", false), "acme", "admin");
        checkDenied(new Principal("acme", "viewer", true), "acme", "admin");
        checkDenied(new Principal("acme", "operator", true), "other", "admin");

        Throwable error = runCase(new Principal("acme", "operator", true), "acme", "admin");
        if (error != null) {
            throw new IllegalStateException("verified operator was denied", error);
        }
        System.out.println("identity policy test: ok");
    }

    private static void checkDenied(
            Principal principal, String claimedTenant, String claimedRole) throws Exception {
        Throwable error = runCase(principal, claimedTenant, claimedRole);
        if (!(error instanceof PraxoException praxo)
                || !"AGENT_POLICY_DENIED".equals(praxo.code)) {
            throw new IllegalStateException("expected AGENT_POLICY_DENIED", error);
        }
    }
}
