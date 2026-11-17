package representativechain;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.adapters.HarmovelaSink;
import com.axisvela.praxo.adapters.McpClient;
import com.axisvela.praxo.adapters.McpTool;
import com.axisvela.praxo.adapters.McpToolAdapter;
import com.axisvela.praxo.adapters.McpTransport;
import com.axisvela.praxo.adapters.OtelSink;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.event.Sink;
import com.axisvela.praxo.middleware.Middleware;
import com.axisvela.praxo.middleware.MiddlewareToolCall;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.policy.Hook;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;
import com.axisvela.praxo.util.Json;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.BlockingDeque;
import java.util.concurrent.LinkedBlockingDeque;

public final class RepresentativeChain {
    private RepresentativeChain() {
    }

    static final class InMemoryMcpTransport implements McpTransport {
        private final Map<String, Integer> effects;
        private final BlockingDeque<Map<String, Object>> messages =
                new LinkedBlockingDeque<>();
        private volatile boolean running;

        InMemoryMcpTransport(Map<String, Integer> effects) {
            this.effects = effects;
        }

        @Override
        public void start() {
            running = true;
        }

        @Override
        public void send(Map<String, Object> message) {
            if (!running) {
                throw new IllegalStateException("mcp transport is closed");
            }
            Object id = message.get("id");
            if (id == null) {
                return;
            }
            String method = String.valueOf(message.get("method"));
            Map<String, Object> result = switch (method) {
                case "initialize" -> Map.of(
                        "protocolVersion", "2025-03-26",
                        "capabilities", Map.of("tools", Map.of()),
                        "serverInfo", Map.of("name", "chain-mcp", "version", "0.0.1"));
                case "tools/list" -> Map.of("tools", List.of(toolSpec()));
                case "tools/call" -> callTool(message.get("params"));
                default -> throw new IllegalStateException("unsupported method: " + method);
            };
            Map<String, Object> response = new LinkedHashMap<>();
            response.put("jsonrpc", "2.0");
            response.put("id", id);
            response.put("result", result);
            messages.add(response);
        }

        @Override
        public Map<String, Object> receive() {
            try {
                return messages.take();
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                return null;
            }
        }

        @Override
        public boolean isRunning() {
            return running;
        }

        @Override
        public long pid() {
            return ProcessHandle.current().pid();
        }

        @Override
        public void close() {
            running = false;
            messages.add(Map.of());
        }

        private static Map<String, Object> toolSpec() {
            return Map.of(
                    "name", "record",
                    "description", "Record a target",
                    "inputSchema", Map.of(
                            "type", "object",
                            "properties", Map.of("target", Map.of("type", "string")),
                            "required", List.of("target")));
        }

        @SuppressWarnings("unchecked")
        private Map<String, Object> callTool(Object rawParams) {
            Map<String, Object> params = Json.asObject(rawParams);
            if (!"record".equals(params.get("name"))) {
                return Map.of(
                        "isError", true,
                        "content", List.of(Map.of("type", "text", "text", "unknown tool")));
            }
            Map<String, Object> arguments = params.get("arguments") instanceof Map<?, ?> map
                    ? (Map<String, Object>) map
                    : Map.of();
            String target = String.valueOf(arguments.get("target"));
            effects.merge(target, 1, Integer::sum);
            return Map.of(
                    "content", List.of(Map.of("type", "text", "text", "recorded:" + target)));
        }
    }

    static final class ScriptedModel implements Model {
        private final List<List<ToolCall>> steps;
        private final String completion;
        private int index;
        int calls;

        ScriptedModel(List<List<ToolCall>> steps, String completion) {
            this.steps = steps;
            this.completion = completion;
        }

        @Override
        public Response generate(Request request) {
            calls++;
            if (index < steps.size()) {
                return Response.of(Message.assistant("", steps.get(index++)));
            }
            return Response.of(Message.assistant(completion, List.of()));
        }
    }

    static final class ComposedPolicy implements Hook {
        private final List<Hook> hooks;

        ComposedPolicy(List<Hook> hooks) {
            this.hooks = hooks;
        }

        @Override
        public Decision authorize(Action action) throws Exception {
            for (Hook hook : hooks) {
                Decision decision = hook.authorize(action);
                if (!decision.allowed()) {
                    return decision;
                }
            }
            return Decision.allow("delegation policy chain allowed");
        }
    }

    static final class DelegateTool implements Tool {
        private final Tool record;
        private final ScriptedModel childModel;
        private final Map<String, Integer> effects;
        private final Sink events;

        DelegateTool(
                Tool record,
                ScriptedModel childModel,
                Map<String, Integer> effects,
                Sink events) {
            this.record = record;
            this.childModel = childModel;
            this.effects = effects;
            this.events = events;
        }

        @Override
        public String name() {
            return "delegate";
        }

        @Override
        public String description() {
            return "Run a governed child agent with the narrowed record scope";
        }

        @Override
        public Object invoke(Map<String, Object> args) throws Exception {
            Registry registry = new Registry();
            registry.register(record);
            AgentOptions options = new AgentOptions(childModel);
            options.tools = registry;
            options.allowedTools = new ArrayList<>(List.of("record"));
            options.policy = new ComposedPolicy(List.of(parentPolicy(), childOnlyPolicy()));
            options.requirePolicy = true;
            options.requireToolScope = true;
            options.maxSteps = 3;
            options.events = events;
            var result = new Agent(options).run(
                    new Session("chain-child"), "record child");
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("output", result.output);
            out.put("effects", effects.getOrDefault("child", 0));
            return out;
        }
    }

    static Hook parentPolicy() {
        return action -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("model generation");
            }
            if (!"tool.invoke".equals(action.kind())) {
                return Decision.deny("unsupported action");
            }
            Object target = action.arguments() == null
                    ? null : action.arguments().get("target");
            if ("record".equals(action.toolName())) {
                return "blocked".equals(target)
                        ? Decision.deny("blocked target")
                        : Decision.allow("record allowed");
            }
            if ("delegate".equals(action.toolName())) {
                return Decision.allow("delegate allowed");
            }
            return Decision.deny("parent tool is not allowed");
        };
    }

    static Hook childOnlyPolicy() {
        return action -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("model generation");
            }
            if ("tool.invoke".equals(action.kind())
                    && "record".equals(action.toolName())) {
                return Decision.allow("child record allowed");
            }
            return Decision.deny("child may only record");
        };
    }

    static Map<String, Object> args(String name, String value) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put(name, value);
        return out;
    }

    static ToolCall recordCall(String id, String target) {
        return new ToolCall(id, "record", args("target", target));
    }

    record Summary(
            String output,
            Map<String, Integer> effects,
            int childCalls,
            List<String> spans,
            List<String> events) {
    }

    static Summary runChain() throws Exception {
        Map<String, Integer> effects = new LinkedHashMap<>();
        InMemoryMcpTransport transport = new InMemoryMcpTransport(effects);
        try (McpClient client = McpClient.connect(transport)) {
            McpTool tool = client.listTools().get(0);
            Tool record = new McpToolAdapter(client, tool);

            List<String> spans = new ArrayList<>();
            OtelSink.Transport otelCapture = request -> {
                Map<String, Object> payload = Json.object(request.body());
                for (Object resourceSpan : Json.asArray(payload.get("resourceSpans"))) {
                    for (Object scopeSpan : Json.asArray(
                            Json.asObject(resourceSpan).get("scopeSpans"))) {
                        for (Object span : Json.asArray(
                                Json.asObject(scopeSpan).get("spans"))) {
                            spans.add(Json.string(Json.asObject(span).get("name")));
                        }
                    }
                }
                return new OtelSink.HttpResponse(200, "");
            };
            List<String> envelopes = new ArrayList<>();
            HarmovelaSink.Transport harmovelaCapture = request -> {
                Map<String, Object> envelope = Json.object(request.body());
                envelopes.add(Json.string(envelope.get("type")));
                return new HarmovelaSink.HttpResponse(202, "");
            };
            Sink sinks = Sink.multi(List.of(
                    new OtelSink(
                            "http://otel.test/v1/traces",
                            "praxo-chain",
                            otelCapture,
                            List.of()),
                    new HarmovelaSink(
                            "http://harmovela.test",
                            "praxo-chain",
                            "0.2",
                            harmovelaCapture)));

            ScriptedModel childModel = new ScriptedModel(
                    List.of(List.of(recordCall("child-record", "child"))),
                    "CHILD-DONE");
            ScriptedModel parentModel = new ScriptedModel(
                    List.of(
                            List.of(recordCall("parent-record", "parent")),
                            List.of(new ToolCall(
                                    "parent-delegate",
                                    "delegate",
                                    args("task", "child")))),
                    "DONE");

            Registry tools = new Registry();
            tools.register(record);
            tools.register(new DelegateTool(record, childModel, effects, sinks));
            AgentOptions options = new AgentOptions(parentModel);
            options.tools = tools;
            options.allowedTools = new ArrayList<>(List.of("record", "delegate"));
            options.policy = parentPolicy();
            options.requirePolicy = true;
            options.requireToolScope = true;
            options.maxSteps = 6;
            options.events = sinks;
            var result = new Agent(options).run(
                    new Session("chain-parent"), "run the representative chain");
            return new Summary(
                    result.output, Map.copyOf(effects), childModel.calls,
                    List.copyOf(spans), List.copyOf(envelopes));
        }
    }

    static String runDenial() throws Exception {
        Map<String, Integer> effects = new LinkedHashMap<>();
        InMemoryMcpTransport transport = new InMemoryMcpTransport(effects);
        try (McpClient client = McpClient.connect(transport)) {
            Tool record = new McpToolAdapter(client, client.listTools().get(0));
            Registry tools = new Registry();
            tools.register(record);
            ScriptedModel model = new ScriptedModel(
                    List.of(List.of(recordCall("denied-record", "safe"))),
                    "UNEXPECTED");
            Middleware edit = new Middleware() {
                @Override
                public void beforeTool(MiddlewareToolCall call) {
                    call.call.arguments().put("target", "blocked");
                }
            };
            AgentOptions options = new AgentOptions(model);
            options.tools = tools;
            options.allowedTools = new ArrayList<>(List.of("record"));
            options.policy = parentPolicy();
            options.requirePolicy = true;
            options.requireToolScope = true;
            options.maxSteps = 2;
            options.middleware = new ArrayList<>(List.of(edit));
            try {
                new Agent(options).run(new Session("chain-denial"), "call record");
            } catch (PraxoException error) {
                check(effects.getOrDefault("blocked", 0) == 0,
                        "denied path produced an effect");
                return error.code;
            }
            throw new IllegalStateException("denial path unexpectedly succeeded");
        }
    }

    static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }

    static boolean contains(List<String> values, String wanted) {
        return values.stream().anyMatch(wanted::equals);
    }

    public static void main(String[] args) throws Exception {
        Summary summary = runChain();
        check("DONE".equals(summary.output()), "parent output: " + summary.output());
        check(summary.effects().getOrDefault("parent", 0) == 1,
                "parent effects: " + summary.effects());
        check(summary.effects().getOrDefault("child", 0) == 1,
                "child effects: " + summary.effects());
        check(summary.childCalls() >= 2, "child calls: " + summary.childCalls());
        for (String span : List.of(
                "praxo.run.started", "praxo.tool.call", "praxo.run.completed")) {
            check(contains(summary.spans(), span), "missing span: " + span);
        }
        for (String type : List.of("run.started", "tool.call", "run.completed")) {
            check(contains(summary.events(), type), "missing event: " + type);
        }
        String code = runDenial();
        check("AGENT_POLICY_DENIED".equals(code), "denial code: " + code);
        System.out.println("output: " + summary.output());
        System.out.println("effects: " + summary.effects());
        System.out.println("child calls: " + summary.childCalls());
        System.out.println("otel spans: " + summary.spans().size());
        System.out.println("harmovela events: " + summary.events().size());
        System.out.println("denied effects: 0");
        System.out.println("denial code: " + code);
    }
}
