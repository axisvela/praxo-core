package com.axisvela.praxo.adapters;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.util.Json;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class McpSelfTest {
    private McpSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        String java = Path.of(System.getProperty("java.home"), "bin", "java")
                .toString();
        String classpath = System.getProperty("java.class.path");
        String serverClass = FakeMcpServer.class.getName();

        try (McpClient client = connect(java, classpath, serverClass,
                "default", null)) {
            require(client.connected(), "client was not connected");
            require("2024-11-05".equals(client.protocolVersion()),
                    "protocol version");
            require("fake-mcp".equals(client.serverInfo().get("name")),
                    "server info");
            List<McpTool> tools = client.listTools();
            require(names(tools).equals(
                    List.of("add", "echo", "fail", "multi")), "tool names");
            McpTool echo = tools.stream()
                    .filter(tool -> tool.name().equals("echo"))
                    .findFirst().orElseThrow();
            require(echo.description().equals("Echo input"),
                    "echo description");
            Map<String, Object> expectedSchema = Json.object("""
                    {
                      "type": "object",
                      "properties": {"text": {"type": "string"}},
                      "required": ["text"]
                    }
                    """);
            require(echo.inputSchema().equals(expectedSchema), "input schema");
            require(echo.toSpec().parameters().equals(echo.inputSchema()),
                    "spec schema");

            require("hello".equals(client.callTool(
                    "echo", Map.of("text", "hello"))), "echo call");
            require(Map.of("sum", 3L).equals(client.callTool(
                    "add", Map.of("a", 1, "b", 2))), "structured call");
            require(List.of("one", "two").equals(
                    client.callTool("multi", Map.of())), "text blocks");
            try {
                client.callTool("fail", Map.of());
                throw new AssertionError("expected MCP tool error");
            } catch (PraxoException error) {
                require("MCP_TOOL_ERROR".equals(error.code), "tool error code");
                require(error.getMessage().contains("boom"), "tool error text");
            }

            Registry registry = new Registry();
            List<McpToolAdapter> adapters = client.registerTools(registry);
            require(registry.size() == 4, "registry size");
            require(adapters.size() == 4, "adapter count");
            McpToolAdapter echoAdapter = adapters.stream()
                    .filter(tool -> tool.name().equals("echo"))
                    .findFirst().orElseThrow();
            require(echoAdapter.spec().parameters().equals(expectedSchema),
                    "adapter schema");
            require("registered".equals(registry.get("echo")
                    .invoke(Map.of("text", "registered"))), "registry invoke");

            require(client.isRunning(), "child not running");
            require(client.pid() > 0, "child pid");
            client.close();
            require(!client.isRunning(), "child still running");
            try {
                client.listTools();
                throw new AssertionError("expected closed client error");
            } catch (PraxoException error) {
                require("MCP_CLOSED".equals(error.code), "closed code");
            }
        }

        try (McpClient client = connect(java, classpath, serverClass,
                "repeated-cursor", null)) {
            try {
                client.listTools();
                throw new AssertionError("expected repeated cursor error");
            } catch (PraxoException error) {
                require("MCP_PAGINATION".equals(error.code),
                        "pagination code");
            }
        }

        try (McpClient client = connect(java, classpath, serverClass,
                "duplicate-name", null)) {
            try {
                client.listTools();
                throw new AssertionError("expected duplicate name error");
            } catch (PraxoException error) {
                require("MCP_DUPLICATE_TOOL".equals(error.code),
                        "duplicate code");
            }
        }

        Path marker = Files.createTempFile("praxo-mcp-", ".txt");
        Files.deleteIfExists(marker);
        try (McpClient client = connect(java, classpath, serverClass,
                "hang", marker)) {
            List<McpTool> tools = client.listTools();
            require(names(tools).equals(List.of("hang")), "hang tools");
            try {
                client.callTool("hang", Map.of(), Duration.ofMillis(150));
                throw new AssertionError("expected timeout");
            } catch (PraxoException error) {
                require("MCP_TIMEOUT".equals(error.code), "timeout code");
            }
            long started = System.nanoTime();
            boolean cancelled = false;
            while (Duration.ofNanos(System.nanoTime() - started)
                    .compareTo(Duration.ofSeconds(3)) < 0) {
                if (Files.exists(marker) && Files.readString(
                        marker, StandardCharsets.UTF_8).contains("cancelled")) {
                    cancelled = true;
                    break;
                }
                Thread.sleep(20);
            }
            require(cancelled, "cancellation notification");
        } finally {
            Files.deleteIfExists(marker);
        }

        System.out.println("mcp self-test passed");
    }

    private static McpClient connect(
            String java,
            String classpath,
            String serverClass,
            String mode,
            Path marker) throws Exception {
        List<String> command = new ArrayList<>(List.of(
                java, "-cp", classpath, serverClass, mode));
        if (marker != null) {
            command.add(marker.toString());
        }
        return McpClient.connect(
                new McpServerConfig(command, Map.of(), null),
                Duration.ofSeconds(5));
    }

    private static List<String> names(List<McpTool> tools) {
        return tools.stream().map(McpTool::name).toList();
    }

    private static void require(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
