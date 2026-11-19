package com.axisvela.praxo.plugin;

import com.axisvela.praxo.util.Json;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

public final class ProcessHost implements AutoCloseable {
    public static final int PROTOCOL_VERSION = 1;
    public static final String CONTROL_SERVICE = "host.control";
    public static final String HEALTH_METHOD = "health";
    public static final String SHUTDOWN_METHOD = "shutdown";
    public static final String CANCEL_METHOD = "cancel";
    public static final String DEFAULT_TOKEN_ENV = "PRAXOVELA_PLUGIN_TOKEN";

    public static final class CallError extends RuntimeException {
        private final String code;

        public CallError(String code, String message) {
            super(message == null || message.isEmpty() ? code : message);
            this.code = normalizeCode(code);
        }

        public String code() {
            return code;
        }
    }

    public static final class Config {
        public String pluginId;
        public String path;
        public List<String> args = new ArrayList<>();
        public String dir;
        public Map<String, String> env;
        public String token = "";
        public String tokenEnvVar = DEFAULT_TOKEN_ENV;
        public Duration startTimeout = Duration.ofSeconds(10);
        public Duration invokeTimeout = Duration.ofSeconds(30);
        public Duration gracePeriod = Duration.ofSeconds(5);
        public int maxFrame = 8 << 20;

        public Config(String pluginId, String path) {
            this.pluginId = pluginId;
            this.path = path;
        }
    }

    private static final Object END = new Object();

    private final Config config;
    private final String token;
    private final AtomicLong sequence = new AtomicLong();
    private final BlockingQueue<Object> responses = new LinkedBlockingQueue<>();
    private final StringBuilder stderr = new StringBuilder();
    private Process process;
    private OutputStream stdin;
    private volatile boolean active;

    public ProcessHost(Config config) {
        if (config.pluginId == null || config.pluginId.isEmpty()) {
            throw new IllegalArgumentException("plugin: PluginID is required");
        }
        if (config.path == null || config.path.isEmpty()) {
            throw new IllegalArgumentException("plugin: path is required");
        }
        this.config = config;
        this.token = config.token.isEmpty() ? randomToken() : config.token;
    }

    public String pluginId() {
        return config.pluginId;
    }

    public boolean isActive() {
        return active;
    }

    public synchronized void start() throws IOException {
        if (process != null) {
            throw new IllegalStateException("plugin: host already started");
        }
        List<String> command = new ArrayList<>();
        command.add(config.path);
        command.addAll(config.args);
        ProcessBuilder builder = new ProcessBuilder(command);
        if (config.dir != null) {
            builder.directory(new java.io.File(config.dir));
        }
        if (config.env != null) {
            builder.environment().clear();
            builder.environment().putAll(config.env);
        }
        builder.environment().put(config.tokenEnvVar, token);
        process = builder.start();
        stdin = process.getOutputStream();
        startReader(process.getInputStream());
        startStderrReader(process.getErrorStream());
        try {
            call(CONTROL_SERVICE, HEALTH_METHOD, new byte[0], config.startTimeout.toMillis());
        } catch (RuntimeException error) {
            terminate();
            throw error;
        }
        active = true;
    }

    public byte[] invoke(String service, String method, byte[] payload) {
        return invoke(service, method, payload, config.invokeTimeout.toMillis());
    }

    public synchronized byte[] invoke(
            String service, String method, byte[] payload, long timeoutMillis) {
        if (!active) {
            throw new CallError("NOT_ACTIVE", "plugin: host is not active");
        }
        return call(service, method, payload, timeoutMillis);
    }

    public synchronized void stop() {
        if (process == null) {
            return;
        }
        try {
            if (active) {
                call(CONTROL_SERVICE, SHUTDOWN_METHOD, new byte[0],
                        config.gracePeriod.toMillis());
            }
        } catch (RuntimeException ignored) {
            // best effort
        }
        active = false;
        terminate();
    }

    public String stderrText() {
        synchronized (stderr) {
            return stderr.toString();
        }
    }

    private byte[] call(String service, String method, byte[] payload, long timeoutMillis) {
        long id = sequence.incrementAndGet();
        String requestId = "req-" + id;
        Map<String, Object> frame = new LinkedHashMap<>();
        frame.put("id", requestId);
        frame.put("version", PROTOCOL_VERSION);
        frame.put("plugin_id", config.pluginId);
        frame.put("service", service);
        frame.put("method", method);
        frame.put("token", token);
        frame.put("payload", Base64.getEncoder().encodeToString(payload));
        byte[] encoded = (Json.stringify(frame) + "\n").getBytes(StandardCharsets.UTF_8);
        if (encoded.length > config.maxFrame) {
            throw new CallError("INVALID_REQUEST", "plugin: request frame too large");
        }
        try {
            stdin.write(encoded);
            stdin.flush();
        } catch (IOException error) {
            throw new CallError("INTERNAL", error.getMessage());
        }
        long deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMillis);
        while (true) {
            long remaining = deadline - System.nanoTime();
            if (remaining <= 0) {
                sendCancel(requestId);
                terminate();
                throw new CallError("TIMEOUT", "plugin: invocation timed out");
            }
            Object item;
            try {
                item = responses.poll(remaining, TimeUnit.NANOSECONDS);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                throw new CallError("INTERNAL", "plugin: interrupted");
            }
            if (item == null) {
                sendCancel(requestId);
                terminate();
                throw new CallError("TIMEOUT", "plugin: invocation timed out");
            }
            if (item == END) {
                String detail = stderrText();
                terminate();
                throw new CallError("INTERNAL",
                        detail.isEmpty() ? "plugin: process exited" : bounded(detail));
            }
            Map<String, Object> response;
            try {
                response = Json.object((String) item);
            } catch (IllegalArgumentException ignored) {
                continue;
            }
            if (!requestId.equals(Json.string(response, "id"))) {
                continue;
            }
            if (!Boolean.TRUE.equals(response.get("ok"))) {
                String code = Json.string(response.get("code"));
                String message = Json.string(response.get("message"));
                throw new CallError(code == null ? "INTERNAL" : code, message);
            }
            String payloadText = Json.string(response.get("payload"));
            if (payloadText == null) {
                return new byte[0];
            }
            try {
                return Base64.getDecoder().decode(payloadText);
            } catch (IllegalArgumentException error) {
                throw new CallError("INTERNAL", "plugin: invalid payload");
            }
        }
    }

    private void sendCancel(String requestId) {
        Map<String, Object> frame = new LinkedHashMap<>();
        frame.put("id", requestId);
        frame.put("version", PROTOCOL_VERSION);
        frame.put("plugin_id", config.pluginId);
        frame.put("service", CONTROL_SERVICE);
        frame.put("method", CANCEL_METHOD);
        frame.put("token", token);
        try {
            stdin.write((Json.stringify(frame) + "\n").getBytes(StandardCharsets.UTF_8));
            stdin.flush();
        } catch (IOException ignored) {
            // best effort
        }
    }

    private void startReader(InputStream stream) {
        Thread thread = new Thread(() -> {
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(stream, StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    responses.offer(line);
                }
            } catch (IOException ignored) {
                // stream closed
            } finally {
                responses.offer(END);
            }
        }, "praxo-plugin-stdout");
        thread.setDaemon(true);
        thread.start();
    }

    private void startStderrReader(InputStream stream) {
        Thread thread = new Thread(() -> {
            byte[] buffer = new byte[4096];
            try {
                int count;
                while ((count = stream.read(buffer)) > 0) {
                    synchronized (stderr) {
                        if (stderr.length() < 16 << 10) {
                            int remaining = (16 << 10) - stderr.length();
                            stderr.append(new String(buffer, 0, Math.min(count, remaining),
                                    StandardCharsets.UTF_8));
                        }
                    }
                }
            } catch (IOException ignored) {
                // stream closed
            }
        }, "praxo-plugin-stderr");
        thread.setDaemon(true);
        thread.start();
    }

    private void terminate() {
        active = false;
        if (process != null) {
            process.destroy();
            try {
                if (!process.waitFor(1, TimeUnit.SECONDS)) {
                    process.destroyForcibly();
                    process.waitFor(1, TimeUnit.SECONDS);
                }
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
            }
        }
        process = null;
        stdin = null;
    }

    private static String normalizeCode(String code) {
        if (code == null) {
            return "INTERNAL";
        }
        return switch (code) {
            case "CAPABILITY_DENIED", "NOT_ACTIVE", "NOT_FOUND", "INVALID_REQUEST",
                    "TIMEOUT", "INTERNAL", "CANCELED" -> code;
            default -> "INTERNAL";
        };
    }

    private static String bounded(String value) {
        return value.length() <= 512 ? value : value.substring(0, 512);
    }

    private static String randomToken() {
        byte[] bytes = new byte[32];
        new java.security.SecureRandom().nextBytes(bytes);
        return java.util.HexFormat.of().formatHex(bytes);
    }

    @Override
    public void close() {
        stop();
    }
}
