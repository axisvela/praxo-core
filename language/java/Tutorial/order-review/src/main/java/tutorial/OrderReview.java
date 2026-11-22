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

import java.net.InetSocketAddress;
import java.net.Proxy;
import java.net.URI;
import java.net.HttpURLConnection;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

public final class OrderReview {
    public static final class ReviewTool implements Tool {
        private final URI origin;
        private final String token;

        ReviewTool(String baseUrl, String token) {
            origin = URI.create(baseUrl);
            if (!"http".equals(origin.getScheme()) || origin.getHost() == null
                    || origin.getRawQuery() != null || origin.getRawFragment() != null
                    || origin.getRawUserInfo() != null
                    || !(origin.getPath().isEmpty() || "/".equals(origin.getPath()))) {
                throw new IllegalArgumentException("Expected local teaching service HTTP origin");
            }
            this.token = token;
        }

        public String name() { return "review_order"; }
        public String description() { return "Read a synthetic order and create a draft, never a refund."; }

        public ToolSpec spec() {
            return new ToolSpec(name(), description(), Map.of("type", "object", "required", List.of("order_id"),
                    "properties", Map.of("order_id", Map.of("type", "string"))), "write");
        }

        private Map<String, Object> request(String path, Map<String, Object> body) throws Exception {
            var connection = (HttpURLConnection) origin.resolve(path).toURL().openConnection(Proxy.NO_PROXY);
            connection.setConnectTimeout(5000);
            connection.setReadTimeout(5000);
            connection.setInstanceFollowRedirects(false);
            connection.setRequestProperty("Authorization", "Bearer " + token);
            try {
                if (body != null) {
                    connection.setRequestMethod("POST");
                    connection.setRequestProperty("Content-Type", "application/json");
                    connection.setRequestProperty("Idempotency-Key", "java-review-1");
                    connection.setDoOutput(true);
                    try (var output = connection.getOutputStream()) {
                        output.write(Json.stringify(body).getBytes(StandardCharsets.UTF_8));
                    }
                }
                int status = connection.getResponseCode();
                if (status != 200 && status != 201) {
                    throw new IllegalStateException("Business service rejected request: " + status);
                }
                try (var input = connection.getInputStream()) {
                    byte[] bytes = input.readNBytes(16385);
                    if (bytes.length > 16384) throw new IllegalStateException("Response too large");
                    return Json.object(new String(bytes, StandardCharsets.UTF_8));
                }
            } finally {
                connection.disconnect();
            }
        }

        public Object invoke(Map<String, Object> args) throws Exception {
            var order = request("/v1/orders/" + args.get("order_id"), null);
            String recommendation = "delayed".equals(order.get("status")) ? "Contact carrier" : "Monitor shipment";
            var draft = request("/v1/orders/" + order.get("id") + "/drafts", Map.of("recommendation", recommendation));
            return Json.stringify(Map.of("order", order, "draft", draft));
        }
    }

    public static String review(String baseUrl, String token, String orderId) throws Exception {
        Model fixture = request -> {
            var last = request.messages().get(request.messages().size() - 1);
            if (Message.TOOL.equals(last.role())) {
                return Response.of(Message.assistant(last.content(), List.of()));
            }
            return Response.of(Message.assistant("", List.of(
                    new ToolCall("review-1", "review_order", Map.of("order_id", orderId)))));
        };
        Registry tools = new Registry();
        tools.register(new ReviewTool(baseUrl, token));
        AgentOptions options = new AgentOptions(fixture);
        options.tools = tools;
        options.maxSteps = 3;
        options.allowedTools = List.of("review_order");
        options.policy = action -> "model.generate".equals(action.kind())
                || ("tool.invoke".equals(action.kind()) && "review_order".equals(action.toolName())
                && action.arguments() != null && "order-100".equals(action.arguments().get("order_id")))
                ? Decision.allow("fixed order scope") : Decision.deny("only order-100 is permitted");
        return new Agent(options).run(new Session("order-review"), "Review " + orderId + "; draft only.").output;
    }

    public static HttpServer serve(String baseUrl, String token, int port) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
        server.createContext("/review/order-100", exchange -> {
            int status = 200;
            String result;
            if (!"/review/order-100".equals(exchange.getRequestURI().toString())) {
                status = 404;
                result = "{\"error\":\"not_found\"}";
            } else if (!"POST".equals(exchange.getRequestMethod())) {
                status = 405;
                result = "{\"error\":\"method_not_allowed\"}";
            } else if (!"Bearer demo-a-token".equals(exchange.getRequestHeaders().getFirst("Authorization"))) {
                status = 401;
                result = "{\"error\":\"unauthenticated\"}";
            } else {
                try { result = review(baseUrl, token, "order-100"); }
                catch (Exception error) { status = 503; result = "{\"error\":\"review_failed\"}"; }
            }
            byte[] bytes = result.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(status, bytes.length);
            try (var output = exchange.getResponseBody()) { output.write(bytes); }
            finally { exchange.close(); }
        });
        server.start();
        return server;
    }

    public static void main(String[] args) throws Exception {
        String baseUrl = System.getenv().getOrDefault("DEMO_BASE_URL", "http://127.0.0.1:8765");
        String token = System.getenv().getOrDefault("DEMO_TOKEN", "demo-a-token");
        if (args.length == 1 && "--serve".equals(args[0])) {
            HttpServer server = serve(baseUrl, token, 8086);
            Runtime.getRuntime().addShutdownHook(new Thread(() -> server.stop(0)));
            System.out.println("Order review: http://127.0.0.1:8086/review/order-100");
        } else {
            System.out.println(review(baseUrl, token, System.getenv().getOrDefault("DEMO_ORDER", "order-100")));
        }
    }
}
