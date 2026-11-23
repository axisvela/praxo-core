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
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class WealthService {
    public record ReviewResult(String output, int reads) {
    }

    @FunctionalInterface
    public interface ReviewFn {
        ReviewResult review(String account) throws Exception;
    }

    private static final Map<String, Object> PORTFOLIO = Map.of(
            "account", "acct-100",
            "currency", "USD",
            "cash", 50000.0,
            "equity", 120000.0,
            "bonds", 80000.0);

    private static final class FixtureModel implements Model {
        @Override
        public Response generate(com.axisvela.praxo.model.Request request) throws Exception {
            int tools = 0;
            for (Message message : request.messages()) {
                if (Message.TOOL.equals(message.role())) {
                    tools++;
                }
            }
            if (tools == 0) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("portfolio-1", "read_portfolio",
                                Map.of("account", "acct-100")))));
            }
            if (tools == 1) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("draft-1", "draft_rebalance",
                                Map.of("account", "acct-100", "target_equity", 55.0)))));
            }
            Map<String, Object> draft = Json.object(lastToolContent(request));
            Map<String, Object> report = new LinkedHashMap<>();
            report.put("advice", "Review the proposed allocation; no trade or transfer was executed.");
            report.put("citations", List.of("portfolio", "risk-policy"));
            report.put("draft", draft);
            report.put("executed_trades", List.of());
            return Response.of(Message.assistant(Json.stringify(report), List.of()));
        }

        private static String lastToolContent(com.axisvela.praxo.model.Request request) {
            String content = "";
            for (Message message : request.messages()) {
                if (Message.TOOL.equals(message.role())) {
                    content = message.content();
                }
            }
            return content;
        }
    }

    public static final class ReadPortfolioTool implements Tool {
        private final int[] reads;
        private final boolean simulateFailure;

        public ReadPortfolioTool(int[] reads, boolean simulateFailure) {
            this.reads = reads;
            this.simulateFailure = simulateFailure;
        }

        public String name() { return "read_portfolio"; }
        public String description() { return "Read the fixed wealth portfolio; no trades."; }

        public ToolSpec spec() {
            return new ToolSpec(name(), description(), Map.of(
                    "type", "object", "required", List.of("account"),
                    "properties", Map.of("account", Map.of("type", "string"))), "read");
        }

        public Object invoke(Map<String, Object> args) {
            reads[0]++;
            if (simulateFailure) throw new IllegalStateException("simulated portfolio dependency unavailable");
            if (!"acct-100".equals(args.get("account"))) throw new IllegalArgumentException("account not found");
            return PORTFOLIO;
        }
    }

    public static final class DraftRebalanceTool implements Tool {
        private final int[] reads;

        public DraftRebalanceTool(int[] reads) {
            this.reads = reads;
        }

        public String name() { return "draft_rebalance"; }
        public String description() { return "Draft a rebalance for human review; never executes a trade."; }

        public ToolSpec spec() {
            return new ToolSpec(name(), description(), Map.of(
                    "type", "object", "required", List.of("account", "target_equity"),
                    "properties", Map.of(
                            "account", Map.of("type", "string"),
                            "target_equity", Map.of("type", "number"))), "write");
        }

        public Object invoke(Map<String, Object> args) {
            reads[0]++;
            if (!"acct-100".equals(args.get("account"))) throw new IllegalArgumentException("account not found");
            double target = ((Number) args.get("target_equity")).doubleValue();
            double total = (double) PORTFOLIO.get("cash") + (double) PORTFOLIO.get("equity") + (double) PORTFOLIO.get("bonds");
            double current = ((double) PORTFOLIO.get("equity") / total) * 100.0;
            Map<String, Object> draft = new LinkedHashMap<>();
            draft.put("draft_id", "draft-1");
            draft.put("account", "acct-100");
            draft.put("status", "draft_only");
            draft.put("action", "review_required");
            draft.put("current_equity_percent", current);
            draft.put("target_equity_percent", target);
            return draft;
        }
    }

    private static boolean authorize(com.axisvela.praxo.policy.Action action) {
        if ("model.generate".equals(action.kind())) return true;
        if (!"tool.invoke".equals(action.kind())) return false;
        Object account = action.arguments() == null ? null : action.arguments().get("account");
        if (!"acct-100".equals(account)) return false;
        if ("read_portfolio".equals(action.toolName())) return true;
        if ("draft_rebalance".equals(action.toolName())) {
            Object target = action.arguments().get("target_equity");
            return target instanceof Number number && number.doubleValue() >= 0 && number.doubleValue() <= 100;
        }
        return false;
    }

    public static ReviewResult review(String account, boolean simulateFailure) throws Exception {
        int[] reads = {0};
        Registry tools = new Registry();
        tools.register(new ReadPortfolioTool(reads, simulateFailure));
        tools.register(new DraftRebalanceTool(reads));
        AgentOptions options = new AgentOptions(new FixtureModel());
        options.tools = tools;
        options.allowedTools = List.of("read_portfolio", "draft_rebalance");
        options.policy = action -> authorize(action)
                ? Decision.allow("fixed account and review-only scope")
                : Decision.deny("account or target outside wealth review scope");
        options.requirePolicy = true;
        options.requireToolScope = true;
        options.maxSteps = 4;
        var result = new Agent(options).run(new Session("wealth-review"),
                "Review the fixed portfolio and propose a draft allocation only.");
        return new ReviewResult(result.output, reads[0]);
    }

    public static HttpServer serve(int port, ReviewFn reviewFn) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
        server.createContext("/healthz", exchange -> {
            byte[] body = "{\"status\":\"ok\"}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, body.length);
            try (var output = exchange.getResponseBody()) { output.write(body); }
            finally { exchange.close(); }
        });
        server.createContext("/review/acct-100", exchange -> {
            int status = 200;
            String body;
            if (!"POST".equals(exchange.getRequestMethod())) {
                status = 405; body = "{\"error\":\"method_not_allowed\"}";
            } else if (!"Bearer demo-wealth-token".equals(exchange.getRequestHeaders().getFirst("Authorization"))) {
                status = 401; body = "{\"error\":\"unauthenticated\"}";
            } else {
                try { body = reviewFn.review("acct-100").output(); }
                catch (Exception error) { status = 503; body = "{\"error\":\"review_failed\"}"; }
            }
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(status, bytes.length);
            try (var output = exchange.getResponseBody()) { output.write(bytes); }
            finally { exchange.close(); }
        });
        server.start();
        return server;
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 1 && "--serve".equals(args[0])) {
            HttpServer server = serve(8090, account -> review(account, false));
            Runtime.getRuntime().addShutdownHook(new Thread(() -> server.stop(0)));
            System.out.println("Wealth review: http://127.0.0.1:8090/review/acct-100");
        } else {
            System.out.println(review("acct-100", false).output());
        }
    }
}
