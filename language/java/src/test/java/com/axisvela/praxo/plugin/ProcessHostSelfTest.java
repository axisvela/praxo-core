package com.axisvela.praxo.plugin;

import com.axisvela.praxo.util.Json;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class ProcessHostSelfTest {
    private ProcessHostSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        if ("1".equals(System.getenv("PRAXO_FAKE_PLUGIN"))) {
            runPlugin();
            return;
        }
        runTests();
        System.out.println("Java process host self-test passed");
    }

    private static void runPlugin() throws Exception {
        String token = Objects.requireNonNullElse(
                System.getenv(ProcessHost.DEFAULT_TOKEN_ENV), "");
        BufferedReader reader = new BufferedReader(
                new InputStreamReader(System.in, StandardCharsets.UTF_8));
        PrintStream out = new PrintStream(System.out, true, StandardCharsets.UTF_8);
        String line;
        while ((line = reader.readLine()) != null) {
            Map<String, Object> request;
            try {
                request = Json.object(line);
            } catch (IllegalArgumentException error) {
                continue;
            }
            Map<String, Object> response = new LinkedHashMap<>();
            response.put("id", Json.string(request, "id"));
            response.put("version", 1);
            if (!token.equals(Json.string(request, "token"))) {
                response.put("ok", false);
                response.put("code", "INVALID_REQUEST");
                response.put("message", "token mismatch");
                out.println(Json.stringify(response));
                continue;
            }
            String method = Json.string(request, "method");
            switch (method) {
                case "health", "cancel", "shutdown" -> {
                    response.put("ok", true);
                    response.put("payload", "");
                    out.println(Json.stringify(response));
                    if ("shutdown".equals(method)) {
                        return;
                    }
                }
                case "echo" -> {
                    response.put("ok", true);
                    response.put("payload", Json.string(request, "payload"));
                    out.println(Json.stringify(response));
                }
                case "denied" -> {
                    response.put("ok", false);
                    response.put("code", "CAPABILITY_DENIED");
                    response.put("message", "denied");
                    out.println(Json.stringify(response));
                }
                case "block" -> Thread.sleep(30_000);
                default -> {
                    response.put("ok", false);
                    response.put("code", "NOT_FOUND");
                    response.put("message", "unknown method");
                    out.println(Json.stringify(response));
                }
            }
        }
    }

    private static void runTests() throws Exception {
        ProcessHost.Config config = new ProcessHost.Config(
                "com.example.echo", pythonExecutable());
        config.args = List.of(fixture().toString());
        config.env = new java.util.HashMap<>(System.getenv());
        config.invokeTimeout = java.time.Duration.ofSeconds(2);
        config.gracePeriod = java.time.Duration.ofSeconds(2);

        try (ProcessHost host = new ProcessHost(config)) {
            host.start();
            check(host.isActive(), "active after start");
            byte[] payload = "{\"text\":\"hi\"}".getBytes(StandardCharsets.UTF_8);
            check(java.util.Arrays.equals(host.invoke("tool.provider", "echo", payload), payload),
                    "echo payload");
            try {
                host.invoke("tool.provider", "denied", new byte[0]);
                throw new AssertionError("expected denied");
            } catch (ProcessHost.CallError error) {
                check("CAPABILITY_DENIED".equals(error.code()), "denied code");
            }
            try {
                host.invoke("tool.provider", "missing", new byte[0]);
                throw new AssertionError("expected missing");
            } catch (ProcessHost.CallError error) {
                check("NOT_FOUND".equals(error.code()), "not found code");
            }
        }

        ProcessHost.Config idle = new ProcessHost.Config("com.example.echo", pythonExecutable());
        idle.args = config.args;
        idle.env = config.env;
        ProcessHost idleHost = new ProcessHost(idle);
        try {
            idleHost.invoke("tool.provider", "echo", new byte[0]);
            throw new AssertionError("expected not active");
        } catch (ProcessHost.CallError error) {
            check("NOT_ACTIVE".equals(error.code()), "not active code");
        }

        ProcessHost.Config slow = new ProcessHost.Config("com.example.echo", pythonExecutable());
        slow.args = config.args;
        slow.env = config.env;
        slow.invokeTimeout = java.time.Duration.ofMillis(200);
        try (ProcessHost host = new ProcessHost(slow)) {
            host.start();
            try {
                host.invoke("tool.provider", "block", new byte[0]);
                throw new AssertionError("expected timeout");
            } catch (ProcessHost.CallError error) {
                check("TIMEOUT".equals(error.code()), "timeout code");
            }
        }
    }

    private static String pythonExecutable() {
        return System.getenv().getOrDefault("PYTHON", "python");
    }

    private static java.nio.file.Path fixture() {
        return java.nio.file.Path.of("tests", "fixtures", "process_plugin.py")
                .toAbsolutePath();
    }

    private static String javaExecutable() {
        String name = System.getProperty("os.name", "").toLowerCase().contains("win")
                ? "java.exe" : "java";
        return java.nio.file.Path.of(System.getProperty("java.home"), "bin", name).toString();
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
