package starter;

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
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;

import java.io.PrintStream;
import java.util.List;
import java.util.Map;

public final class App {
    private App() {
    }

    static final class FixtureModel implements Model {
        private final String target;

        FixtureModel(String target) {
            this.target = target;
        }

        @Override
        public Response generate(Request request) {
            Message last = request.messages().get(request.messages().size() - 1);
            if (Message.TOOL.equals(last.role())) {
                return Response.of(Message.assistant("recorded", List.of()));
            }
            ToolCall call = new ToolCall("record-1", "record", Map.of("target", target));
            return Response.of(Message.assistant("", List.of(call)));
        }
    }

    static final class RecordTool implements Tool {
        private int calls;

        @Override
        public String name() {
            return "record";
        }

        @Override
        public String description() {
            return "Record a target in an in-memory counter.";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            calls += 1;
            return "recorded";
        }

        int calls() {
            return calls;
        }
    }

    public record Built(Agent agent, RecordTool tool) {
    }

    static Built buildAgent(String target) {
        Registry tools = new Registry();
        RecordTool tool = new RecordTool();
        tools.register(tool);
        AgentOptions options = new AgentOptions(new FixtureModel(target));
        options.tools = tools;
        options.maxSteps = 3;
        options.allowedTools = List.of("record");
        options.policy = (Action action) -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("model generation");
            }
            if ("tool.invoke".equals(action.kind())) {
                Object value = action.arguments() == null
                        ? null
                        : action.arguments().get("target");
                return "record".equals(action.toolName()) && "public".equals(value)
                        ? Decision.allow("public target")
                        : Decision.deny("only the public target is permitted");
            }
            return Decision.deny("unsupported action");
        };
        return new Built(new Agent(options), tool);
    }

    public static void run(PrintStream out) throws Exception {
        Built allowed = buildAgent("public");
        var result = allowed.agent().run(
                new Session("starter-public"), "Record the requested target.");
        if (!"recorded".equals(result.output) || allowed.tool().calls != 1) {
            throw new IllegalStateException(
                    "allow verification failed: output=" + result.output
                            + " effects=" + allowed.tool().calls);
        }
        out.println("allow: recorded; effects=1");

        Built denied = buildAgent("private");
        try {
            denied.agent().run(
                    new Session("starter-private"), "Record the requested target.");
        } catch (PraxoException error) {
            if (!"AGENT_POLICY_DENIED".equals(error.code)) {
                throw error;
            }
            if (denied.tool().calls != 0) {
                throw new IllegalStateException(
                        "denied call produced effects=" + denied.tool().calls);
            }
            out.println("deny: policy rejected; effects=0");
            return;
        }
        throw new IllegalStateException("private target was not denied");
    }

    public static void main(String[] args) throws Exception {
        run(System.out);
    }
}
