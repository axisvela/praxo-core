package tutorial;

import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;
import com.axisvela.praxo.util.Json;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

public final class ArchitectureGraph {
    public static final String SCOPE_ID = "architecture-100";
    public static final String SCOPE_KEY = "architecture_id";
    public static final String TOOL = "read_graph";
    public static final String ACTION = "draft_findings";
    public static final String ERROR = "GRAPH_DATA_UNAVAILABLE";

    public record Outcome(String output, int reads) {}

    private static final class FixtureTool implements Tool {
        private final AtomicInteger reads;
        private final boolean simulateFailure;

        FixtureTool(AtomicInteger reads, boolean simulateFailure) {
            this.reads = reads;
            this.simulateFailure = simulateFailure;
        }

        public String name() { return TOOL; }
        public String description() { return "Review architecture graph fixtures and draft a review-only result."; }

        public ToolSpec spec() {
            return new ToolSpec(name(), description(),
                    Map.of("type", "object", "required", List.of(SCOPE_KEY, "action"),
                            "properties", Map.of(SCOPE_KEY, Map.of("type", "string"),
                                    "action", Map.of("type", "string"))), "write");
        }

        public Object invoke(Map<String, Object> args) {
            reads.incrementAndGet();
            if (!SCOPE_ID.equals(args.get(SCOPE_KEY))) {
                throw new IllegalArgumentException("scope outside fixture");
            }
            if (simulateFailure) {
                throw new IllegalStateException(ERROR);
            }
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("id", SCOPE_ID);
            result.put("assets", 4);
            result.put("findings", 2);
            result.put("status", "draft_only");
            result.put("review_required", true);
            result.put("writes", 0);
            result.put("source", "fixture");
            return Json.stringify(result);
        }
    }

    public static Outcome run(String scope, boolean simulateFailure) throws Exception {
        AtomicInteger reads = new AtomicInteger();
        Model fixture = request -> {
            Message last = request.messages().get(request.messages().size() - 1);
            if (Message.TOOL.equals(last.role())) {
                String toolResult = last.content();
                return Response.of(Message.assistant(
                        "{\"stage\":\"" + "findings_drafted" + "\",\"result\":" + toolResult
                                + ",\"writes\":0}", List.of()));
            }
            return Response.of(Message.assistant("", List.of(
                    new ToolCall("tool-1", TOOL, Map.of(SCOPE_KEY, scope, "action", ACTION)))));
        };
        Registry tools = new Registry();
        tools.register(new FixtureTool(reads, simulateFailure));
        AgentOptions options = new AgentOptions(fixture);
        options.tools = tools;
        options.maxSteps = 3;
        options.allowedTools = List.of(TOOL);
        options.policy = action -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("deterministic tutorial review");
            }
            if (!"tool.invoke".equals(action.kind()) || action.arguments() == null) {
                return Decision.deny("unsupported action");
            }
            Object scopeArg = action.arguments().get(SCOPE_KEY);
            Object draft = action.arguments().get("action");
            if (!SCOPE_ID.equals(scopeArg)) {
                return Decision.deny("only " + SCOPE_ID + " is in scope");
            }
            if (TOOL.equals(action.toolName()) && ACTION.equals(draft)) {
                return Decision.allow(SCOPE_ID + " review-only draft");
            }
            return Decision.deny("only a review-only draft is allowed");
        };
        String output = new Agent(options)
                .run(new Session("architecture-graph"), "Review architecture graph fixtures and draft a review-only result.").output;
        return new Outcome(output, reads.get());
    }

    public static void main(String[] args) throws Exception {
        String scope = SCOPE_ID;
        boolean failure = false;
        for (int index = 0; index < args.length; index++) {
            if ("--architecture".equals(args[index]) && index + 1 < args.length) {
                scope = args[++index];
            } else if ("--simulate-failure".equals(args[index])) {
                failure = true;
            }
        }
        Outcome outcome = run(scope, failure);
        System.out.println(outcome.output());
        System.out.println("reads=" + outcome.reads());
    }
}
