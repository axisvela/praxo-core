package com.axisvela.praxo.adapters;

import java.util.Map;

public interface McpTransport extends AutoCloseable {
    void start();

    void send(Map<String, Object> message);

    Map<String, Object> receive();

    boolean isRunning();

    long pid();

    @Override
    void close();
}
