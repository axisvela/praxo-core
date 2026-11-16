package service;

import com.axisvela.praxo.adapters.OpenAIConfig;
import com.axisvela.praxo.adapters.OpenAICompatibleModel;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.tool.FuncTool;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.util.Json;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ProxySelector;
import java.net.URI;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class ServiceExample {
    private ServiceExample() {
    }

    record ApiResponse(int status, Map<String, Object> body) {
    }

    static Agent createAgent(Model model) {
        Registry tools = new Registry();
        tools.register(new FuncTool("get_time",
                "Return the current UTC time in ISO 8601 format.",
                args -> Instant.now().toString()));
        AgentOptions options = new AgentOptions(model);
        options.tools = tools;
        options.systemPrompt = "You are a concise service assistant. Use tools when they help.";
        options.maxSteps = 4;
        options.allowedTools = List.of("get_time");
        options.policy = action -> {
            if (action.kind().equals("model.generate")) {
                return Decision.allow("model generation");
            }
            if (action.kind().equals("tool.invoke")) {
                return "get_time".equals(action.toolName())
                        ? Decision.allow("get_time is permitted")
                        : Decision.deny("only get_time is permitted");
            }
            return Decision.deny("unsupported action");
        };
        return new Agent(options);
    }

    static ApiResponse handle(
            Agent agent, String tenant, String method, String path,
            String principal, String body) {
        if (method.equals("GET") && path.equals("/healthz")) {
            return new ApiResponse(200, Map.of("status", "ok"));
        }
        if (!method.equals("POST") || !path.equals("/run")) {
            return new ApiResponse(404, Map.of("error", "not found"));
        }
        if (principal == null || principal.isEmpty()) {
            return new ApiResponse(401, Map.of("error", "missing X-Praxo-Principal"));
        }
        Map<String, Object> payload;
        try {
            payload = Json.object(body);
        } catch (RuntimeException error) {
            return new ApiResponse(400, Map.of("error", "invalid JSON body"));
        }
        Object promptValue = payload.get("prompt");
        if (!(promptValue instanceof String prompt) || prompt.isEmpty()) {
            return new ApiResponse(400, Map.of("error", "prompt is required"));
        }
        try {
            Session session = new Session(principal);
            session.tenantId = tenant;
            session.workspaceId = "service";
            String output = agent.run(session, prompt).output;
            return new ApiResponse(200, Map.of("output", output));
        } catch (Exception error) {
            return new ApiResponse(500, Map.of("error", error.getMessage()));
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length > 0 && args[0].equals("--test")) {
            runTests();
            System.out.println("service test: ok");
            System.exit(0);
            return;
        }
        if (args.length > 1 && args[0].equals("--revoke-token")) {
            String url = System.getenv().getOrDefault("PRAXO_REVOCATION_URL", "");
            if (url.isEmpty()) {
                System.err.println("PRAXO_REVOCATION_URL is required");
                System.exit(1);
            }
            RevocationClient.revoke(
                    args[1],
                    authClient(),
                    URI.create(url),
                    envOr("PRAXO_INTROSPECTION_CLIENT_ID",
                            System.getenv().getOrDefault("PRAXO_OIDC_CLIENT_ID", "")),
                    envOr("PRAXO_INTROSPECTION_CLIENT_SECRET",
                            System.getenv().getOrDefault("PRAXO_OIDC_CLIENT_SECRET", "")));
            System.out.println("token revoked");
            return;
        }
        Model model = new OpenAICompatibleModel(new OpenAIConfig(
                envOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
                envOr("PRAXO_API_KEY", ""),
                envOr("PRAXO_MODEL", "llama3.2"),
                60,
                Map.of()));
        String tenant = envOr("PRAXO_TENANT", "local");
        serve(createAgent(model), createAuthenticator(tenant));
    }

    private static HttpClient authClient() {
        int seconds = 2;
        try {
            seconds = Integer.parseInt(envOr("PRAXO_OIDC_TIMEOUT", "2"));
        } catch (NumberFormatException ignored) {
        }
        return HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(Math.max(1, seconds)))
                .build();
    }

    private static RequestAuthenticator createAuthenticator(String tenant) {
        String url = System.getenv().getOrDefault("PRAXO_INTROSPECTION_URL", "");
        if (!url.isEmpty()) {
            return new IntrospectionAuthenticator(
                    authClient(),
                    URI.create(url),
                    envOr("PRAXO_INTROSPECTION_CLIENT_ID",
                            System.getenv().getOrDefault("PRAXO_OIDC_CLIENT_ID", "")),
                    envOr("PRAXO_INTROSPECTION_CLIENT_SECRET",
                            System.getenv().getOrDefault("PRAXO_OIDC_CLIENT_SECRET", "")),
                    envOr("PRAXO_OIDC_TENANT_CLAIM", "tenant"));
        }
        return new ContextAuthenticator(tenant);
    }

    private static void runTests() {
        runAuthTests();
        Agent agent = createAgent(new FakeModel());
        check(handle(agent, "local", "GET", "/healthz", null, "").status() == 200);
        check(handle(agent, "local", "POST", "/run", null, "{\"prompt\":\"hi\"}").status() == 401);
        check(handle(agent, "local", "POST", "/run", "user-1", "not json").status() == 400);
        ApiResponse ok = handle(agent, "local", "POST", "/run", "user-1", "{\"prompt\":\"hi\"}");
        check(ok.status() == 200 && "hello from the service".equals(ok.body().get("output")));
    }

    private static void runAuthTests() {
        Instant now = Instant.now();
        String active = "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"local\","
                + "\"exp\":" + now.plusSeconds(60).getEpochSecond() + "}";
        HttpServer activeServer = startProvider(active, 200);
        try {
            IntrospectionAuthenticator authenticator = new IntrospectionAuthenticator(
                    directClient(),
                    URI.create("http://127.0.0.1:" + activeServer.getAddress().getPort()
                            + "/introspect"),
                    "", "", "tenant");
            AuthenticatedPrincipal principal = authenticator.authenticate(
                    null, "Bearer opaque", now);
            check(principal != null
                    && "user-1".equals(principal.subject())
                    && "local".equals(principal.tenant()));
        } finally {
            activeServer.stop(0);
        }

        HttpServer inactiveServer = startProvider("{\"active\":false}", 200);
        try {
            IntrospectionAuthenticator authenticator = new IntrospectionAuthenticator(
                    directClient(),
                    URI.create("http://127.0.0.1:" + inactiveServer.getAddress().getPort()
                            + "/introspect"),
                    "", "", "tenant");
            check(authenticator.authenticate(null, "Bearer opaque", now) == null);
        } finally {
            inactiveServer.stop(0);
        }

        HttpServer missingExpServer = startProvider(
                "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"local\"}", 200);
        try {
            IntrospectionAuthenticator authenticator = new IntrospectionAuthenticator(
                    directClient(),
                    URI.create("http://127.0.0.1:" + missingExpServer.getAddress().getPort()
                            + "/introspect"),
                    "", "", "tenant");
            check(authenticator.authenticate(null, "Bearer opaque", now) == null);
        } finally {
            missingExpServer.stop(0);
        }

        HttpServer closed = startProvider("{}", 200);
        int closedPort = closed.getAddress().getPort();
        closed.stop(0);
        IntrospectionAuthenticator unavailable = new IntrospectionAuthenticator(
                directClient(),
                URI.create("http://127.0.0.1:" + closedPort + "/introspect"),
                "", "", "tenant");
        check(unavailable.authenticate(null, "Bearer opaque", now) == null);

        HttpServer revokeServer = startProvider("{}", 200);
        try {
            RevocationClient.revoke(
                    "opaque",
                    directClient(),
                    URI.create("http://127.0.0.1:" + revokeServer.getAddress().getPort()
                            + "/revoke"),
                    "", "");
        } catch (Exception error) {
            throw new IllegalStateException("revocation success path failed", error);
        } finally {
            revokeServer.stop(0);
        }

        HttpServer revokeFailure = startProvider("{}", 503);
        try {
            RevocationClient.revoke(
                    "opaque",
                    directClient(),
                    URI.create("http://127.0.0.1:" + revokeFailure.getAddress().getPort()
                            + "/revoke"),
                    "", "");
            throw new IllegalStateException("revocation failure was accepted");
        } catch (IllegalStateException error) {
            check("token revocation failed".equals(error.getMessage()));
        } catch (Exception error) {
            throw new IllegalStateException("revocation failure path failed", error);
        } finally {
            revokeFailure.stop(0);
        }
    }

    private static HttpClient directClient() {
        return HttpClient.newBuilder()
                .proxy(ProxySelector.of(null))
                .build();
    }

    private static HttpServer startProvider(String introspection, int revokeStatus) {
        try {
            HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            server.createContext("/introspect", exchange -> {
                exchange.getRequestBody().readAllBytes();
                byte[] body = introspection.getBytes(StandardCharsets.UTF_8);
                exchange.sendResponseHeaders(200, body.length);
                exchange.getResponseBody().write(body);
                exchange.close();
            });
            server.createContext("/revoke", exchange -> {
                exchange.getRequestBody().readAllBytes();
                byte[] body = "{}".getBytes(StandardCharsets.UTF_8);
                exchange.sendResponseHeaders(revokeStatus, body.length);
                exchange.getResponseBody().write(body);
                exchange.close();
            });
            server.start();
            return server;
        } catch (IOException error) {
            throw new IllegalStateException("mock provider failed", error);
        }
    }

    private static void check(boolean condition) {
        if (!condition) {
            throw new IllegalStateException("service test failed");
        }
    }

    private static void serve(Agent agent, RequestAuthenticator authenticator)
            throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 8080), 0);
        server.createContext("/", exchange -> {
            byte[] body = exchange.getRequestBody().readAllBytes();
            AuthenticatedPrincipal principal = authenticator.authenticate(
                    exchange.getRequestHeaders().getFirst("X-Praxo-Principal"),
                    exchange.getRequestHeaders().getFirst("Authorization"),
                    Instant.now());
            if (principal == null) {
                write(exchange, new ApiResponse(401, Map.of("error", "unauthorized")));
                return;
            }
            ApiResponse result = handle(
                    agent,
                    principal.tenant(),
                    exchange.getRequestMethod(),
                    exchange.getRequestURI().getPath(),
                    principal.subject(),
                    new String(body, StandardCharsets.UTF_8));
            write(exchange, result);
        });
        server.start();
        System.out.println("listening on http://127.0.0.1:8080");
    }

    private static void write(HttpExchange exchange, ApiResponse result) throws IOException {
        byte[] encoded = Json.stringify(result.body()).getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(result.status(), encoded.length);
        exchange.getResponseBody().write(encoded);
        exchange.close();
    }

    private static String envOr(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isEmpty() ? fallback : value;
    }

    private static final class FakeModel implements Model {
        @Override
        public Response generate(Request request) {
            return Response.of(Message.assistant("hello from the service", List.of()));
        }
    }
}
