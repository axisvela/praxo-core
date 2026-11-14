package mcp;

import com.axisvela.praxo.adapters.McpClient;
import com.axisvela.praxo.adapters.McpTool;
import com.axisvela.praxo.adapters.McpTransport;
import com.axisvela.praxo.tool.Registry;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class McpExample {
    private McpExample() {
    }

    static final class InProcessTransport implements McpTransport {
        private final Deque<Map<String, Object>> messages = new ArrayDeque<>();
        private boolean running;

        @Override
        public void start() {
            running = true;
        }

        @Override
        @SuppressWarnings("unchecked")
        public void send(Map<String, Object> message) {
            String method = String.valueOf(message.get("method"));
            Object id = message.get("id");
            if (id == null) {
                return;
            }
            Map<String, Object> result = switch (method) {
                case "initialize" -> Map.of(
                        "protocolVersion", "2025-03-26",
                        "capabilities", Map.of("tools", Map.of()),
                        "serverInfo", Map.of("name", "example-mcp", "version", "1.0.0"));
                case "tools/list" -> Map.of("tools", tools());
                case "tools/call" -> callTool((Map<String, Object>) message.get("params"));
                default -> throw new IllegalStateException("method not found: " + method);
            };
            Map<String, Object> response = new LinkedHashMap<>();
            response.put("jsonrpc", "2.0");
            response.put("id", id);
            response.put("result", result);
            messages.add(response);
        }

        @Override
        public Map<String, Object> receive() {
            return messages.removeFirst();
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
        }

        private static List<Map<String, Object>> tools() {
            return List.of(
                    Map.of(
                            "name", "echo",
                            "description", "Echo input",
                            "inputSchema", Map.of(
                                    "type", "object",
                                    "properties", Map.of("text", Map.of("type", "string")),
                                    "required", List.of("text"))),
                    Map.of(
                            "name", "add",
                            "description", "Add two integers",
                            "inputSchema", Map.of(
                                    "type", "object",
                                    "properties", Map.of(
                                            "a", Map.of("type", "integer"),
                                            "b", Map.of("type", "integer")),
                                    "required", List.of("a", "b"))));
        }

        @SuppressWarnings("unchecked")
        private static Map<String, Object> callTool(Map<String, Object> params) {
            String name = String.valueOf(params.get("name"));
            Map<String, Object> arguments = params.get("arguments") instanceof Map<?, ?> map
                    ? (Map<String, Object>) map
                    : Map.of();
            if ("echo".equals(name)) {
                return Map.of(
                        "content", List.of(Map.of(
                                "type", "text",
                                "text", String.valueOf(arguments.getOrDefault("text", "")))),
                        "isError", false);
            }
            if ("add".equals(name)) {
                int sum = ((Number) arguments.getOrDefault("a", 0)).intValue()
                        + ((Number) arguments.getOrDefault("b", 0)).intValue();
                return Map.of(
                        "content", List.of(Map.of("type", "text", "text", String.valueOf(sum))),
                        "structuredContent", Map.of("sum", sum),
                        "isError", false);
            }
            return Map.of(
                    "content", List.of(Map.of("type", "text", "text", "unknown tool")),
                    "isError", true);
        }
    }

    public static void main(String[] args) throws Exception {
        InProcessTransport transport = new InProcessTransport();
        try (McpClient client = McpClient.connect(transport)) {
            List<McpTool> tools = client.listTools();
            Registry registry = new Registry();
            client.registerTools(registry);
            Object result = client.callTool("add", Map.of("a", 2, "b", 3));
            List<String> names = tools.stream().map(McpTool::name).sorted().toList();
            if (!names.equals(List.of("add", "echo"))
                    || !(result instanceof Map<?, ?> map)
                    || !Integer.valueOf(5).equals(map.get("sum"))) {
                throw new IllegalStateException("mcp example failed");
            }
            System.out.println("Java MCP example passed");
        }
    }
}
