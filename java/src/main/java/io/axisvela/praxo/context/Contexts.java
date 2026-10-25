package io.axisvela.praxo.context;

import io.axisvela.praxo.model.ContentBlock;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.ToolCall;
import io.axisvela.praxo.util.Json;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public final class Contexts {
    public static final int MAX_AGENTS_MD_BYTES = 64 << 10;
    public static final String COMPACT_MARKER_PREFIX = "[context compacted:";
    public static final String SUMMARY_MARKER_PREFIX = "[context summary:";
    public static final String DEFAULT_SUMMARY_PROMPT =
            "Summarize the conversation so far. Preserve decisions, open tasks, "
                    + "tool results, constraints, and user preferences. Be concise.";

    private Contexts() {
    }

    public static int estimateTokens(List<Message> messages) {
        int total = 0;
        for (Message message : messages) {
            total += 4 + byteLength(message.content()) / 4
                    + byteLength(message.toolId()) / 4;
            for (ContentBlock block : message.contentBlocks()) {
                total += 4 + byteLength(block.text()) / 4
                        + byteLength(block.imageUrl()) / 4
                        + byteLength(block.data()) / 4;
            }
            for (ToolCall call : message.toolCalls()) {
                total += 4 + byteLength(call.name()) / 4;
                total += byteLength(Json.stringify(call.arguments())) / 4;
            }
        }
        return total;
    }

    public static String truncateToTokens(String value, int tokens) {
        if (tokens <= 0) {
            return "";
        }
        int limit = tokens * 4;
        byte[] raw = value.getBytes(StandardCharsets.UTF_8);
        if (raw.length <= limit) {
            return value;
        }
        if (limit <= 16) {
            return new String(raw, 0, limit, StandardCharsets.UTF_8);
        }
        return new String(raw, 0, limit - 16, StandardCharsets.UTF_8)
                + "\n[truncated]";
    }

    public static String loadAgentsMd(List<String> paths) {
        StringBuilder builder = new StringBuilder();
        int used = 0;
        for (String rawPath : paths) {
            if (rawPath == null || rawPath.trim().isEmpty()) {
                continue;
            }
            String text;
            try {
                text = Files.readString(Path.of(rawPath), StandardCharsets.UTF_8).trim();
            } catch (IOException error) {
                throw new IllegalStateException(
                        "agent: read AGENTS.md " + rawPath + ": " + error, error);
            }
            if (text.isEmpty()) {
                continue;
            }
            String header = "## AGENTS.md: " + rawPath + "\n";
            String chunk = header + text;
            int size = byteLength(chunk);
            if (used + size > MAX_AGENTS_MD_BYTES) {
                int remaining = MAX_AGENTS_MD_BYTES - used;
                if (remaining <= byteLength(header)) {
                    break;
                }
                byte[] raw = chunk.getBytes(StandardCharsets.UTF_8);
                if (builder.length() > 0) {
                    builder.append("\n\n");
                }
                builder.append(new String(raw, 0, remaining, StandardCharsets.UTF_8));
                builder.append("\n[truncated]");
                break;
            }
            if (builder.length() > 0) {
                builder.append("\n\n");
            }
            builder.append(chunk);
            used += size;
        }
        return builder.toString();
    }

    private static int byteLength(String value) {
        return value == null ? 0 : value.getBytes(StandardCharsets.UTF_8).length;
    }

    static List<Message> systemMessages(
            List<Message> messages, boolean skipSummary) {
        List<Message> out = new ArrayList<>();
        for (Message message : messages) {
            if (!message.role().equals(Message.SYSTEM)) {
                continue;
            }
            String content = message.content() == null ? "" : message.content();
            if (content.startsWith(COMPACT_MARKER_PREFIX)) {
                continue;
            }
            if (skipSummary && content.startsWith(SUMMARY_MARKER_PREFIX)) {
                continue;
            }
            out.add(message);
        }
        return out;
    }

    static List<Message> restMessages(List<Message> messages) {
        List<Message> out = new ArrayList<>();
        for (Message message : messages) {
            if (!message.role().equals(Message.SYSTEM)) {
                out.add(message);
            }
        }
        return out;
    }

    static Message withContent(Message message, String content) {
        return new Message(message.role(), content, message.contentBlocks(),
                message.toolCalls(), message.toolId());
    }
}
