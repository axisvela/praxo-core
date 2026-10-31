package com.axisvela.praxo.toolcall;

import com.axisvela.praxo.util.Json;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class ToolCalls {
    public record Parsed(
            String callId,
            String name,
            String operation,
            String resource,
            String risk,
            String reason,
            String idempotencyKey,
            Map<String, Object> input) {
    }

    private static final Pattern DSML_INVOKE =
            Pattern.compile("<｜｜DSML｜｜invoke\\s+name=\"([^\"]+)\"\\s*>");
    private static final Pattern DSML_PARAM = Pattern.compile(
            "<｜｜DSML｜｜parameter\\s+name=\"([^\"]+)\"(?:\\s+string=\"([^\"]+)\")?\\s*>(.*?)</｜｜DSML｜｜parameter>",
            Pattern.DOTALL);
    private static final Pattern DSML_SINGULAR = Pattern.compile(
            "<｜｜DSML｜｜tool_call\\s+name=\"([^\"]+)\"\\s*>\\s*(.*?)\\s*</｜｜DSML｜｜tool_call>",
            Pattern.DOTALL);
    private static final Pattern XML_TOOL = Pattern.compile(
            "<tool_call\\s+name=\"([^\"]+)\"\\s*>\\s*(.*?)\\s*</tool_call>",
            Pattern.DOTALL);
    private static final Pattern INVOKE_NAME =
            Pattern.compile("<tool_name>\\s*([^<]+?)\\s*</tool_name>");
    private static final Pattern INVOKE_ATTR =
            Pattern.compile("<parameters\\s+actual=\"(.*?)\">\\s*</parameters>",
                    Pattern.DOTALL);
    private static final Pattern INVOKE_BODY =
            Pattern.compile("<parameters>\\s*(\\{.*?)\\s*</parameters>",
                    Pattern.DOTALL);
    private static final Pattern TAG_TOOL = Pattern.compile(
            "<([a-zA-Z][\\w-]*(?:\\.[\\w-]+)+)>\\s*(\\{.*?)\\s*(?:</[a-zA-Z][\\w.-]*>|$)",
            Pattern.DOTALL);
    private static final Pattern PLAIN_TOOL =
            Pattern.compile("^\\s*([a-zA-Z][\\w.-]*)\\s+(\\{.*\\})\\s*$",
                    Pattern.MULTILINE);
    private static final Pattern TODO =
            Pattern.compile("<todo_(\\w+?)>(.*?)</todo_\\w+>", Pattern.DOTALL);
    private static final Pattern SKILL = Pattern.compile(
            "<skill\\.install\\s+([^>]*)>(.*?)</skill\\.install>",
            Pattern.DOTALL);
    private static final Pattern EXCESS_NEWLINES = Pattern.compile("\\n{3,}");

    private static final List<Pattern> STRIP = List.of(
            Pattern.compile("<｜｜DSML｜｜tool_calls>.*?(?:</｜｜DSML｜｜tool_calls>|$)",
                    Pattern.DOTALL),
            Pattern.compile("<｜｜DSML｜｜tool_call\\s+name=\"[^\"]+\"\\s*>.*?(?:</｜｜DSML｜｜tool_call>|$)",
                    Pattern.DOTALL),
            Pattern.compile("<tool_call\\s+name=\"[^\"]+\"\\s*>.*?(?:</tool_call>|$)",
                    Pattern.DOTALL),
            Pattern.compile("<tool_call_invoke>.*?(?:</tool_call_invoke>|$)",
                    Pattern.DOTALL),
            Pattern.compile("<[a-zA-Z][\\w-]*(?:\\.[\\w-]+)+>\\s*\\{.*?(?:</[a-zA-Z][\\w.-]*>|$)",
                    Pattern.DOTALL));

    private ToolCalls() {
    }

    public static Parsed parse(String content) {
        Parsed call = parseJson(content);
        if (call != null) {
            return withId(call);
        }
        List<java.util.function.Function<String, Parsed>> parsers = List.of(
                ToolCalls::parseDsml,
                ToolCalls::parseXml,
                ToolCalls::parseInvoke,
                ToolCalls::parseTag,
                ToolCalls::parseTodo,
                ToolCalls::parseSkillInstall,
                ToolCalls::parsePlain);
        for (java.util.function.Function<String, Parsed> parser : parsers) {
            call = parser.apply(content);
            if (call != null) {
                return withId(call);
            }
        }
        return null;
    }

    public static String stripMarkup(String content) {
        String out = content;
        for (Pattern pattern : STRIP) {
            out = pattern.matcher(out).replaceAll("");
        }
        out = EXCESS_NEWLINES.matcher(out).replaceAll("\n\n");
        return out.trim();
    }

    public static Map<String, Object> parseInputJson(String raw) {
        try {
            Object value = Json.parse(raw.trim());
            return value instanceof Map<?, ?> ? Json.asObject(value) : null;
        } catch (RuntimeException ignored) {
            try {
                Object value = Json.parse(raw.replace("\\", "\\\\").trim());
                return value instanceof Map<?, ?> ? Json.asObject(value) : null;
            } catch (RuntimeException ignoredAgain) {
                return null;
            }
        }
    }

    private static Parsed parseJson(String content) {
        try {
            Object value = Json.parse(content);
            if (!(value instanceof Map<?, ?>)) {
                return null;
            }
            Map<String, Object> map = Json.asObject(value);
            String name = Json.string(map.get("name"));
            if (name == null || name.isEmpty()) {
                return null;
            }
            Map<String, Object> input = map.get("input") instanceof Map<?, ?>
                    ? Json.asObject(map.get("input"))
                    : new LinkedHashMap<>();
            return new Parsed(
                    "", name,
                    stringOrEmpty(map.get("operation")),
                    stringOrEmpty(map.get("resource")),
                    stringOrEmpty(map.get("risk")),
                    stringOrEmpty(map.get("reason")),
                    stringOrEmpty(map.get("idempotency_key")),
                    input);
        } catch (RuntimeException error) {
            return null;
        }
    }

    private static Parsed parseDsml(String content) {
        if (!content.contains("<｜｜DSML｜｜")) {
            return null;
        }
        if (!content.contains("<｜｜DSML｜｜tool_calls>")) {
            Matcher match = DSML_SINGULAR.matcher(content);
            if (!match.find()) {
                return null;
            }
            Map<String, Object> parsed = parseInputJson(match.group(2));
            return parsed == null
                    ? parsedCall(match.group(1), Map.of("content", match.group(2).trim()))
                    : parsedCall(match.group(1), parsed);
        }
        Matcher invoke = DSML_INVOKE.matcher(content);
        if (!invoke.find()) {
            return null;
        }
        Map<String, Object> input = new LinkedHashMap<>();
        Matcher params = DSML_PARAM.matcher(content);
        while (params.find()) {
            String raw = params.group(3).trim();
            try {
                input.put(params.group(1), Json.parse(raw));
            } catch (RuntimeException error) {
                input.put(params.group(1), raw);
            }
        }
        return parsedCall(invoke.group(1), input);
    }

    private static Parsed parseXml(String content) {
        Matcher match = XML_TOOL.matcher(content);
        String name = null;
        String raw = null;
        while (match.find()) {
            name = match.group(1);
            raw = match.group(2);
        }
        if (name == null) {
            return null;
        }
        Map<String, Object> input = parseInputJson(raw);
        return input == null ? null : parsedCall(name, input);
    }

    private static Parsed parseInvoke(String content) {
        if (!content.contains("<tool_call_invoke>")) {
            return null;
        }
        Matcher name = INVOKE_NAME.matcher(content);
        if (!name.find()) {
            return null;
        }
        String raw = "";
        Matcher attr = INVOKE_ATTR.matcher(content);
        if (attr.find()) {
            raw = attr.group(1).replace("\\\"", "\"");
        } else {
            Matcher body = INVOKE_BODY.matcher(content);
            if (body.find()) {
                raw = body.group(1);
            }
        }
        Map<String, Object> input = raw.trim().isEmpty()
                ? new LinkedHashMap<>()
                : parseInputJson(raw);
        return input == null ? null : parsedCall(name.group(1).trim(), input);
    }

    private static Parsed parseTag(String content) {
        Matcher match = TAG_TOOL.matcher(content);
        String name = null;
        String raw = null;
        while (match.find()) {
            name = match.group(1);
            raw = match.group(2);
        }
        if (name == null) {
            return null;
        }
        Map<String, Object> input = parseInputJson(raw);
        return input == null ? null : parsedCall(name, input);
    }

    private static Parsed parseTodo(String content) {
        if (!content.contains("<todo_")) {
            return null;
        }
        Matcher match = TODO.matcher(content);
        if (!match.find()) {
            return null;
        }
        String raw = match.group(2).trim();
        Map<String, Object> input;
        try {
            Object parsed = Json.parse(raw);
            input = parsed instanceof Map<?, ?>
                    ? Json.asObject(parsed)
                    : Map.of("content", raw);
        } catch (RuntimeException error) {
            input = Map.of("content", raw);
        }
        return parsedCall("todo." + match.group(1), input);
    }

    private static Parsed parseSkillInstall(String content) {
        if (!content.contains("<skill.install")) {
            return null;
        }
        Matcher match = SKILL.matcher(content);
        if (!match.find()) {
            return null;
        }
        Map<String, Object> input = new LinkedHashMap<>();
        for (String pair : match.group(1).trim().split(" ")) {
            if (pair.isEmpty()) {
                continue;
            }
            int index = pair.indexOf('=');
            if (index < 0) {
                continue;
            }
            String key = pair.substring(0, index).replace("\"", "");
            String value = pair.substring(index + 1).replaceAll("^[ \"\\s]+|[ \"\\s\\\\]+$", "");
            input.put(key, value);
        }
        if (!input.containsKey("url") || input.get("url").toString().isEmpty()) {
            input.put("name", match.group(2).trim());
        }
        return parsedCall("skill.install", input);
    }

    private static Parsed parsePlain(String content) {
        Matcher match = PLAIN_TOOL.matcher(content);
        String name = null;
        String raw = null;
        while (match.find()) {
            name = match.group(1);
            raw = match.group(2);
        }
        if (name == null || !name.contains(".")) {
            return null;
        }
        Map<String, Object> input = parseInputJson(raw);
        return input == null ? null : parsedCall(name, input);
    }

    private static Parsed parsedCall(String name, Map<String, Object> input) {
        return new Parsed("", name, "", "", "", "", "", input);
    }

    private static Parsed withId(Parsed call) {
        return new Parsed(
                "tc-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16),
                call.name(), call.operation(), call.resource(), call.risk(),
                call.reason(), call.idempotencyKey(), call.input());
    }

    private static String stringOrEmpty(Object value) {
        String text = Json.string(value);
        return text == null ? "" : text;
    }
}
