package com.axisvela.praxo.adapters;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.Version;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.util.Json;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicLong;

public final class McpClient implements AutoCloseable {
    public static final String DEFAULT_PROTOCOL_VERSION = "2024-11-05";
    private static final Duration DEFAULT_TIMEOUT = Duration.ofSeconds(30);

    private final McpServerConfig config;
    private final Duration timeout;
    private final String clientName;
    private final String clientVersion;
    private final String requestedProtocolVersion;
    private final Map<Long, CompletableFuture<Map<String, Object>>> pending =
            new ConcurrentHashMap<>();
    private final AtomicLong nextId = new AtomicLong(1);
    private final Object writeLock = new Object();

    private Process process;
    private BufferedWriter writer;
    private Thread reader;
    private volatile boolean closed;
    private volatile Throwable readError;
    private volatile String protocolVersion = "";
    private volatile Map<String, Object> serverInfo = Map.of();
    private volatile Map<String, Object> serverCapabilities = Map.of();

    public McpClient(McpServerConfig config) {
        this(config, DEFAULT_TIMEOUT);
    }

    public McpClient(McpServerConfig config, Duration timeout) {
        this(config, timeout, "praxo-core", Version.SDK_VERSION,
                DEFAULT_PROTOCOL_VERSION);
    }

    public McpClient(
            McpServerConfig config,
            Duration timeout,
            String clientName,
            String clientVersion,
            String protocolVersion) {
        this.config = config;
        this.timeout = timeout;
        this.clientName = clientName;
        this.clientVersion = clientVersion;
        this.requestedProtocolVersion = protocolVersion;
    }

    public static McpClient connect(McpServerConfig config) throws Exception {
        return connect(config, DEFAULT_TIMEOUT);
    }

    public static McpClient connect(McpServerConfig config, Duration timeout)
            throws Exception {
        McpClient client = new McpClient(config, timeout);
        client.start();
        return client;
    }

    public synchronized void start() throws Exception {
        if (process != null) {
            return;
        }
        if (closed) {
            throw PraxoException.mcpClosed("mcp: client is closed");
        }
        if (config.command().isEmpty()) {
            throw PraxoException.mcpTransport("mcp: command is required");
        }
        ProcessBuilder builder = new ProcessBuilder(config.command());
        if (config.cwd() != null) {
            builder.directory(config.cwd().toFile());
        }
        builder.environment().putAll(config.env());
        builder.redirectError(ProcessBuilder.Redirect.DISCARD);
        try {
            process = builder.start();
        } catch (IOException error) {
            throw PraxoException.mcpTransport(
                    "mcp: failed to start server: " + error.getMessage());
        }
        writer = new BufferedWriter(new OutputStreamWriter(
                process.getOutputStream(), StandardCharsets.UTF_8));
        reader = new Thread(this::readLoop, "praxo-mcp-reader");
        reader.setDaemon(true);
        reader.start();
        try {
            initialize();
        } catch (Exception error) {
            close();
            throw error;
        }
    }

    public boolean isRunning() {
        Process current = process;
        return current != null && current.isAlive();
    }

    public long pid() {
        Process current = process;
        return current == null ? -1 : current.pid();
    }

    public boolean connected() {
        return !closed && !protocolVersion.isEmpty();
    }

    public String protocolVersion() {
        return protocolVersion;
    }

    public Map<String, Object> serverInfo() {
        return serverInfo;
    }

    public Map<String, Object> serverCapabilities() {
        return serverCapabilities;
    }

    public List<McpTool> listTools() throws Exception {
        return listTools(timeout);
    }

    public List<McpTool> listTools(Duration requestTimeout) throws Exception {
        List<McpTool> tools = new ArrayList<>();
        Set<String> names = new HashSet<>();
        Set<String> cursors = new HashSet<>();
        String cursor = null;
        while (true) {
            Map<String, Object> params = new LinkedHashMap<>();
            if (cursor != null) {
                params.put("cursor", cursor);
            }
            Map<String, Object> result = request(
                    "tools/list", params.isEmpty() ? null : params, requestTimeout);
            Object raw = result.get("tools");
            if (raw == null) {
                raw = List.of();
            }
            if (!(raw instanceof List<?> items)) {
                throw PraxoException.mcpProtocol(
                        "mcp: tools/list tools must be a list");
            }
            for (Object item : items) {
                McpTool tool = McpProtocol.parseTool(item);
                if (!names.add(tool.name())) {
                    throw PraxoException.mcpDuplicateTool(
                            "mcp: duplicate tool " + tool.name());
                }
                tools.add(tool);
            }
            Object next = result.get("nextCursor");
            if (next == null || "".equals(next)) {
                break;
            }
            if (!(next instanceof String text)) {
                throw PraxoException.mcpProtocol(
                        "mcp: tools/list nextCursor must be a string");
            }
            if (!cursors.add(text)) {
                throw PraxoException.mcpPagination(
                        "mcp: repeated tool pagination cursor");
            }
            cursor = text;
        }
        tools.sort(Comparator.comparing(McpTool::name));
        return tools;
    }

    public Object callTool(String name, Map<String, Object> arguments)
            throws Exception {
        return callTool(name, arguments, timeout);
    }

    public Object callTool(
            String name,
            Map<String, Object> arguments,
            Duration requestTimeout) throws Exception {
        if (name == null || name.isEmpty()) {
            throw PraxoException.mcpProtocol("mcp: tool name is required");
        }
        Map<String, Object> args = arguments == null
                ? new LinkedHashMap<>() : arguments;
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("name", name);
        params.put("arguments", args);
        Map<String, Object> result = request("tools/call", params, requestTimeout);
        if (Boolean.TRUE.equals(result.get("isError"))) {
            throw PraxoException.mcpToolError(
                    "mcp: tool " + name + " failed: "
                            + String.join("\n",
                                    McpProtocol.textContents(result)));
        }
        Object structured = result.get("structuredContent");
        if (structured != null) {
            return structured;
        }
        List<String> texts = McpProtocol.textContents(result);
        if (texts.isEmpty()) {
            return null;
        }
        if (texts.size() == 1) {
            return texts.get(0);
        }
        return texts;
    }

    public List<McpToolAdapter> registerTools(Registry registry) throws Exception {
        List<McpTool> tools = listTools();
        List<McpToolAdapter> adapters = new ArrayList<>(tools.size());
        for (McpTool tool : tools) {
            McpToolAdapter adapter = new McpToolAdapter(this, tool);
            registry.register(adapter);
            adapters.add(adapter);
        }
        return adapters;
    }

    @Override
    public synchronized void close() {
        if (closed) {
            return;
        }
        closed = true;
        for (Long id : new ArrayList<>(pending.keySet())) {
            cancel(id, "client closed");
        }
        try {
            if (writer != null) {
                writer.close();
            }
        } catch (IOException ignored) {
        }
        Process current = process;
        if (current != null) {
            try {
                if (!current.waitFor(200, TimeUnit.MILLISECONDS)) {
                    current.destroy();
                    if (!current.waitFor(2, TimeUnit.SECONDS)) {
                        current.destroyForcibly();
                        current.waitFor();
                    }
                }
            } catch (InterruptedException error) {
                current.destroyForcibly();
                Thread.currentThread().interrupt();
            }
        }
        if (reader != null && reader != Thread.currentThread()) {
            try {
                reader.join(1000);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
            }
        }
        failAll(PraxoException.mcpClosed("mcp: client closed"));
    }

    private void initialize() throws Exception {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("protocolVersion", requestedProtocolVersion);
        params.put("capabilities", new LinkedHashMap<>());
        Map<String, Object> clientInfo = new LinkedHashMap<>();
        clientInfo.put("name", clientName);
        clientInfo.put("version", clientVersion);
        params.put("clientInfo", clientInfo);
        Map<String, Object> result = request("initialize", params, timeout);
        Object negotiated = result.get("protocolVersion");
        if (!(negotiated instanceof String version) || version.isEmpty()) {
            throw PraxoException.mcpHandshake(
                    "mcp: initialize returned no protocol version");
        }
        protocolVersion = version;
        if (result.get("serverInfo") instanceof Map<?, ?> info) {
            serverInfo = McpProtocol.copyObject(info);
        }
        if (result.get("capabilities") instanceof Map<?, ?> capabilities) {
            serverCapabilities = McpProtocol.copyObject(capabilities);
        }
        notify("notifications/initialized", null);
    }

    private Map<String, Object> request(
            String method,
            Map<String, Object> params,
            Duration requestTimeout) throws Exception {
        if (closed) {
            throw PraxoException.mcpClosed("mcp: client is closed");
        }
        if (readError != null) {
            throw PraxoException.mcpClosed("mcp: connection closed");
        }
        long id = nextId.getAndIncrement();
        CompletableFuture<Map<String, Object>> future = new CompletableFuture<>();
        pending.put(id, future);
        Map<String, Object> message = new LinkedHashMap<>();
        message.put("jsonrpc", "2.0");
        message.put("id", id);
        message.put("method", method);
        if (params != null) {
            message.put("params", params);
        }
        Duration effective = requestTimeout == null ? timeout : requestTimeout;
        try {
            send(message);
            Map<String, Object> response = future.get(
                    effective.toMillis(), TimeUnit.MILLISECONDS);
            return McpProtocol.result(method, response);
        } catch (TimeoutException error) {
            pending.remove(id);
            cancel(id, "timeout");
            throw PraxoException.mcpTimeout(
                    "mcp: " + method + " timed out after "
                            + effective.toMillis() + "ms");
        } catch (InterruptedException error) {
            pending.remove(id);
            cancel(id, "cancelled");
            Thread.currentThread().interrupt();
            throw PraxoException.mcpCancelled("mcp: " + method + " cancelled");
        } catch (ExecutionException error) {
            pending.remove(id);
            Throwable cause = error.getCause();
            if (cause instanceof RuntimeException runtime) {
                throw runtime;
            }
            throw PraxoException.mcpClosed("mcp: connection closed");
        } finally {
            pending.remove(id);
        }
    }

    private void notify(String method, Map<String, Object> params) {
        Map<String, Object> message = new LinkedHashMap<>();
        message.put("jsonrpc", "2.0");
        message.put("method", method);
        if (params != null) {
            message.put("params", params);
        }
        try {
            send(message);
        } catch (RuntimeException ignored) {
        }
    }

    private void cancel(long id, String reason) {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("requestId", id);
        params.put("reason", reason);
        notify("notifications/cancelled", params);
    }

    private void send(Map<String, Object> message) {
        synchronized (writeLock) {
            if (writer == null) {
                throw PraxoException.mcpTransport(
                        "mcp: transport is not started");
            }
            try {
                writer.write(Json.stringify(message));
                writer.write('\n');
                writer.flush();
            } catch (IOException error) {
                throw PraxoException.mcpTransport(
                        "mcp: write failed: " + error.getMessage());
            }
        }
    }

    private void readLoop() {
        try (BufferedReader input = new BufferedReader(new InputStreamReader(
                process.getInputStream(), StandardCharsets.UTF_8))) {
            String line;
            while ((line = input.readLine()) != null) {
                if (line.isBlank()) {
                    continue;
                }
                Map<String, Object> message;
                try {
                    message = Json.object(line);
                } catch (RuntimeException error) {
                    failAll(PraxoException.mcpProtocol(
                            "mcp: server sent invalid JSON"));
                    return;
                }
                if (!"2.0".equals(message.get("jsonrpc"))) {
                    failAll(PraxoException.mcpProtocol(
                            "mcp: invalid JSON-RPC version"));
                    return;
                }
                if (!(message.get("id") instanceof Number number)) {
                    continue;
                }
                long id = number.longValue();
                CompletableFuture<Map<String, Object>> future = pending.remove(id);
                if (future != null) {
                    future.complete(message);
                }
            }
        } catch (IOException error) {
            readError = error;
        }
        if (readError == null) {
            failAll(PraxoException.mcpClosed("mcp: connection closed"));
        } else {
            failAll(PraxoException.mcpTransport(
                    "mcp: read failed: " + readError.getMessage()));
        }
    }

    private void failAll(PraxoException error) {
        for (Long id : new ArrayList<>(pending.keySet())) {
            CompletableFuture<Map<String, Object>> future = pending.remove(id);
            if (future != null) {
                future.completeExceptionally(error);
            }
        }
    }

}
