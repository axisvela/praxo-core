package advanceddelegation;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.model.ToolSpec;
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
        private final String toolName;
        private final Map<String, Object> arguments;
        private final String completion;
        private int calls;

        FixtureModel(String toolName, Map<String, Object> arguments, String completion) {
            this.toolName = toolName;
            this.arguments = arguments;
            this.completion = completion;
        }

        @Override
        public Response generate(Request request) {
            calls += 1;
            Message last = request.messages().get(request.messages().size() - 1);
            if (Message.TOOL.equals(last.role())) {
                return Response.of(Message.assistant(completion, List.of()));
            }
            ToolCall call = new ToolCall("call-" + calls, toolName, arguments);
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
            return "Record a child result in an in-memory counter.";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            calls += 1;
            return "recorded:" + args.getOrDefault("target", "");
        }

        public ToolSpec spec() {
            return new ToolSpec(
                    name(),
                    description(),
                    Map.of(
                            "type", "object",
                            "required", List.of("target"),
                            "properties", Map.of("target", Map.of("type", "string"))),
                    "write");
        }

        int calls() {
            return calls;
        }
    }

    static final class ParentOnlyTool implements Tool {
        @Override
        public String name() {
            return "parent_only";
        }

        @Override
        public String description() {
            return "A tool that must remain outside the child scope.";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            return "parent-effect";
        }
    }

    static Agent buildChild(RecordTool record) {
        Registry tools = new Registry();
        tools.register(record);
        AgentOptions options = new AgentOptions(
                new FixtureModel("record", Map.of("target", "delegated"), "child-recorded"));
        options.tools = tools;
        options.maxSteps = 3;
        options.allowedTools = List.of("record");
        options.policy = (Action action) -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("child generation");
            }
            if ("tool.invoke".equals(action.kind())) {
                return "record".equals(action.toolName())
                        ? Decision.allow("child may only record")
                        : Decision.deny("child may only record");
            }
            return Decision.deny("unsupported action");
        };
        return new Agent(options);
    }

    static final class DelegateTool implements Tool {
        private final RecordTool record;

        DelegateTool(RecordTool record) {
            this.record = record;
        }

        @Override
        public String name() {
            return "delegate";
        }

        @Override
        public String description() {
            return "Run the child agent with a restricted tool scope.";
        }

        @Override
        public Object invoke(Map<String, Object> args) throws Exception {
            Agent child = buildChild(record);
            var result = child.run(
                    new Session("advanced-delegation-child"),
                    String.valueOf(args.getOrDefault("task", "")));
            return Map.of("output", result.output, "effects", record.calls());
        }
    }

    static Agent buildParent(RecordTool record) {
        Registry tools = new Registry();
        tools.register(new DelegateTool(record));
        tools.register(new ParentOnlyTool());
        AgentOptions options = new AgentOptions(
                new FixtureModel(
                        "delegate",
                        Map.of("task", "record the delegated result"),
                        "parent-done"));
        options.tools = tools;
        options.maxSteps = 3;
        options.allowedTools = List.of("delegate", "parent_only");
        options.policy = (Action action) -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("parent generation");
            }
            if ("tool.invoke".equals(action.kind())) {
                return "delegate".equals(action.toolName())
                                || "parent_only".equals(action.toolName())
                        ? Decision.allow("parent may delegate but not record")
                        : Decision.deny("parent may delegate but not record");
            }
            return Decision.deny("unsupported action");
        };
        return new Agent(options);
    }

    public static void run(PrintStream out) throws Exception {
        RecordTool record = new RecordTool();
        var result = buildParent(record).run(
                new Session("advanced-delegation-parent"),
                "Delegate the record operation to the child agent.");
        if (!"parent-done".equals(result.output) || record.calls() != 1) {
            throw new IllegalStateException(
                    "delegation failed: output=" + result.output
                            + " effects=" + record.calls());
        }
        out.println("delegation: child recorded; parent scope enforced");

        Registry direct = new Registry();
        direct.register(record);
        AgentOptions options = new AgentOptions(
                new FixtureModel("record", Map.of("target", "parent"), "unexpected"));
        options.tools = direct;
        options.maxSteps = 3;
        options.allowedTools = List.of("record");
        options.policy = (Action action) -> "model.generate".equals(action.kind())
                ? Decision.allow("parent generation")
                : Decision.deny("parent may not record");
        try {
            new Agent(options).run(
                    new Session("advanced-delegation-direct"),
                    "Record directly.");
        } catch (PraxoException error) {
            if (!"AGENT_POLICY_DENIED".equals(error.code)) {
                throw error;
            }
            if (record.calls() != 1) {
                throw new IllegalStateException("denied parent call produced a child effect");
            }
            out.println("deny: parent record blocked; child effect unchanged");
            return;
        }
        throw new IllegalStateException("parent recorded outside the delegated scope");
    }

    public static void main(String[] args) throws Exception {
        run(System.out);
    }
}
