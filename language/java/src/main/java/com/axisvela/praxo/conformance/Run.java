package com.axisvela.praxo.conformance;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.checkpoint.Allowlist;
import com.axisvela.praxo.context.ContextBudget;
import com.axisvela.praxo.context.Contexts;
import com.axisvela.praxo.event.Event;
import com.axisvela.praxo.event.Sink;
import com.axisvela.praxo.jsonschema.JsonSchema;
import com.axisvela.praxo.jsonschema.ValidationError;
import com.axisvela.praxo.memory.MemoryRecord;
import com.axisvela.praxo.memory.MemoryStore;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.plugin.Manifest;
import com.axisvela.praxo.plugin.Plugin;
import com.axisvela.praxo.policy.PathChecker;
import com.axisvela.praxo.stream.Streams;
import com.axisvela.praxo.toolcall.ToolCalls;
import com.axisvela.praxo.util.Json;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class Run {
    public static void main(String[] args) throws Exception {
        Path root = ConformanceUtil.repoRoot();
        List<String> failures = runAll(root);
        List<String> parity = Parity.check();
        if (failures.isEmpty() && parity.isEmpty()) {
            System.out.println(
                    "all spec vectors and Java parity checks passed");
            return;
        }
        for (String failure : failures) {
            System.out.println(failure);
        }
        for (String failure : parity) {
            System.out.println("parity: " + failure);
        }
        System.out.println(failures.size() + " vector(s) failed, "
                + parity.size() + " parity gap(s)");
        System.exit(1);
    }

    static List<String> runAll(Path root) throws Exception {
        String version = ConformanceUtil.readString(
                root.resolve("spec").resolve("SPEC_VERSION")).trim();
        List<String> failures = new ArrayList<>();
        Map<String, String> seen = new HashMap<>();
        for (Path path : ConformanceUtil.vectorFiles(root)) {
            Map<String, Object> file = Json.object(
                    ConformanceUtil.readString(path));
            String group = ConformanceUtil.string(file, "group");
            String name = path.getFileName().toString().replace(".json", "");
            if (!version.equals(ConformanceUtil.string(file, "specVersion"))) {
                failures.add(name + ": specVersion mismatch");
            }
            if (!name.equals(group)) {
                failures.add(name + ": group mismatch");
            }
            for (Object item : ConformanceUtil.array(file.get("vectors"))) {
                Map<String, Object> vector = ConformanceUtil.object(item);
                String id = ConformanceUtil.string(vector, "id");
                String previous = seen.putIfAbsent(id, group);
                if (previous != null) {
                    failures.add(group + "/" + id + ": duplicate id");
                }
                try {
                    runVector(group, vector);
                } catch (Exception error) {
                    failures.add(group + "/" + id + ": "
                            + error.getClass().getSimpleName() + ": "
                            + error.getMessage());
                }
            }
        }
        return failures;
    }

    static void runVector(String group, Map<String, Object> vector)
            throws Exception {
        switch (group) {
            case "toolcall" -> runToolcall(vector);
            case "jsonschema" -> runJsonschema(vector);
            case "plugin" -> runPlugin(vector);
            case "memory" -> runMemory(vector);
            case "event" -> runEvent(vector);
            case "stream" -> runStream(vector);
            case "checkpoint" -> runCheckpoint(vector);
            case "policy" -> runPolicy(vector);
            case "context" -> runContext(vector);
            case "middleware" -> MiddlewareRun.run(vector);
            case "agent-loop" -> AgentRun.run(vector);
            default -> throw new IllegalArgumentException(
                    "no runner for group " + group);
        }
    }

    private static void runToolcall(Map<String, Object> vector) {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        String operation = ConformanceUtil.string(input, "operation");
        String content = ConformanceUtil.string(input, "content");
        if ("strip".equals(operation)) {
            String got = ToolCalls.stripMarkup(content == null ? "" : content);
            ConformanceUtil.check(
                    got.equals(ConformanceUtil.string(expect, "text")),
                    "strip: got " + got);
            return;
        }
        ToolCalls.Parsed call = ToolCalls.parse(content == null ? "" : content);
        if (ConformanceUtil.bool(expect, "nil", false)) {
            ConformanceUtil.check(call == null, "expected nil");
            return;
        }
        ConformanceUtil.check(call != null, "expected a tool call");
        ConformanceUtil.check(
                call.name().equals(ConformanceUtil.string(expect, "name")),
                "name: got " + call.name());
        Object expectedInput = expect.get("input");
        ConformanceUtil.check(
                ConformanceUtil.deepEquals(
                        call.input(),
                        expectedInput == null ? Map.of() : expectedInput),
                "input: got " + Json.stringify(call.input()));
    }

    private static void runJsonschema(Map<String, Object> vector) {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        List<ValidationError> errors = JsonSchema.validate(
                ConformanceUtil.object(input.get("schema")),
                input.get("data"));
        List<String> got = new ArrayList<>();
        for (ValidationError error : errors) {
            got.add(error.path());
        }
        got.sort(Comparator.naturalOrder());
        List<String> want = new ArrayList<>();
        if (expect.get("errorPaths") != null) {
            for (Object item : ConformanceUtil.array(expect.get("errorPaths"))) {
                want.add(String.valueOf(item));
            }
        }
        want.sort(Comparator.naturalOrder());
        ConformanceUtil.check(
                (errors.isEmpty()) == ConformanceUtil.bool(expect, "valid", false),
                "valid mismatch");
        ConformanceUtil.check(
                ConformanceUtil.deepEquals(got, want),
                "errorPaths: got " + got);
    }

    private static void runPlugin(Map<String, Object> vector) {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        String raw = input.get("raw") != null
                ? String.valueOf(input.get("raw"))
                : Json.stringify(input.get("manifest"));
        Manifest manifest = null;
        try {
            manifest = Plugin.parseManifest(raw);
        } catch (PraxoException error) {
            if (!error.code.equals("PLUGIN_INVALID_MANIFEST")) {
                throw error;
            }
        }
        ConformanceUtil.check(
                (manifest != null) == ConformanceUtil.bool(expect, "valid", false),
                "valid mismatch");
        if (manifest == null) {
            return;
        }
        if (expect.get("id") != null) {
            ConformanceUtil.check(
                    manifest.id().equals(ConformanceUtil.string(expect, "id")),
                    "id mismatch");
        }
        if (expect.get("kind") != null) {
            ConformanceUtil.check(
                    manifest.kind().equals(ConformanceUtil.string(expect, "kind")),
                    "kind mismatch");
        }
    }

    private static void runMemory(Map<String, Object> vector) throws Exception {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        MemoryStore store = new MemoryStore();
        if (input.get("puts") != null) {
            for (Object item : ConformanceUtil.array(input.get("puts"))) {
                Map<String, Object> put = ConformanceUtil.object(item);
                Map<String, Object> raw = ConformanceUtil.object(put.get("record"));
                MemoryRecord record = new MemoryRecord(
                        ConformanceUtil.string(raw, "id"),
                        ConformanceUtil.string(raw, "frame"),
                        ConformanceUtil.string(raw, "content"),
                        raw.get("metadata") == null
                                ? Map.of()
                                : ConformanceUtil.object(raw.get("metadata")),
                        ConformanceUtil.string(raw, "createdAt"));
                store.put(ConformanceUtil.string(put, "session"), record);
            }
        }
        List<MemoryRecord> records = store.search(
                ConformanceUtil.string(input, "session"),
                ConformanceUtil.string(input, "query"),
                input.get("limit") == null ? 0
                        : ConformanceUtil.integer(input, "limit"));
        List<String> ids = new ArrayList<>();
        List<String> contents = new ArrayList<>();
        for (MemoryRecord record : records) {
            ids.add(record.id());
            contents.add(record.content());
        }
        Object wantIds = expect.get("ids");
        Object wantContents = expect.get("contents");
        ConformanceUtil.check(
                ConformanceUtil.deepEquals(
                        ids.isEmpty() ? null : ids,
                        wantIds == null || ((List<?>) wantIds).isEmpty() ? null : wantIds),
                "ids: got " + ids);
        ConformanceUtil.check(
                ConformanceUtil.deepEquals(
                        contents.isEmpty() ? null : contents,
                        wantContents == null || ((List<?>) wantContents).isEmpty()
                                ? null : wantContents),
                "contents: got " + contents);
    }

    private static void runEvent(Map<String, Object> vector) throws Exception {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        List<Event> events = new ArrayList<>();
        if (input.get("events") != null) {
            for (Object item : ConformanceUtil.array(input.get("events"))) {
                events.add(new Event(String.valueOf(item), "s1", null, null, null));
            }
        }
        String sink = input.get("sink") == null
                ? "filter" : ConformanceUtil.string(input, "sink");
        if (sink.equals("multi")) {
            int count = Math.max(1, input.get("sinkCount") == null
                    ? 1 : ConformanceUtil.integer(input, "sinkCount"));
            List<Sink> sinks = new ArrayList<>();
            List<ConformanceUtil.RecordingSink> recs = new ArrayList<>();
            for (int index = 0; index < count; index++) {
                ConformanceUtil.RecordingSink rec =
                        new ConformanceUtil.RecordingSink();
                recs.add(rec);
                sinks.add(rec);
            }
            Sink multi = Sink.multi(sinks);
            for (Event event : events) {
                multi.emit(event);
            }
            List<Object> got = new ArrayList<>();
            for (ConformanceUtil.RecordingSink rec : recs) {
                got.add(rec.types.isEmpty() ? null : rec.types);
            }
            ConformanceUtil.check(
                    ConformanceUtil.deepEquals(got, expect.get("perSink")),
                    "perSink: got " + got);
            return;
        }
        ConformanceUtil.RecordingSink rec =
                new ConformanceUtil.RecordingSink();
        Set<String> allowed = null;
        if (input.get("predicateTypes") instanceof List<?> list) {
            allowed = new LinkedHashSet<>();
            for (Object item : list) {
                allowed.add(String.valueOf(item));
            }
        }
        final Set<String> predicateTypes = allowed;
        Sink filter = Sink.filter(rec,
                event -> predicateTypes == null || predicateTypes.contains(event.type()));
        for (Event event : events) {
            filter.emit(event);
        }
        ConformanceUtil.check(
                ConformanceUtil.deepEquals(
                        rec.types.isEmpty() ? null : rec.types,
                        expect.get("delivered")),
                "delivered: got " + rec.types);
    }

    private static void runStream(Map<String, Object> vector) {
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        ConformanceUtil.check(
                ConformanceUtil.deepEquals(Streams.KINDS, expect.get("kinds")),
                "kinds: got " + Streams.KINDS);
    }

    private static void runCheckpoint(Map<String, Object> vector) {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        Allowlist allow = new Allowlist();
        if (input.get("registered") != null) {
            for (Object item : ConformanceUtil.array(input.get("registered"))) {
                allow.register(String.valueOf(item), LinkedHashMap::new);
            }
        }
        String operation = input.get("operation") == null
                ? "roundtrip" : ConformanceUtil.string(input, "operation");
        if (operation.equals("roundtrip")) {
            String data = allow.marshal(
                    ConformanceUtil.string(input, "type"), input.get("value"));
            Object got = allow.unmarshal(data);
            ConformanceUtil.check(
                    ConformanceUtil.deepEquals(got, expect.get("value")),
                    "value: got " + Json.stringify(got));
            return;
        }
        try {
            if (operation.equals("marshal")) {
                allow.marshal(ConformanceUtil.string(input, "type"), input.get("value"));
            } else if (operation.equals("unmarshal")) {
                Map<String, Object> envelope = new LinkedHashMap<>();
                envelope.put("type", input.get("type"));
                envelope.put("data", input.get("value"));
                allow.unmarshal(Json.stringify(envelope));
            } else {
                throw new IllegalArgumentException("unknown operation");
            }
        } catch (PraxoException error) {
            ConformanceUtil.check(
                    error.code.equals(ConformanceUtil.string(expect, "errorCode")),
                    "errorCode: got " + error.code);
            return;
        }
        ConformanceUtil.check(
                expect.get("errorCode") == null, "expected an error");
    }

    private static void runPolicy(Map<String, Object> vector) throws Exception {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        Path base = Files.createTempDirectory("praxo-policy-");
        try {
            if (input.get("makeDirs") != null) {
                for (Object item : ConformanceUtil.array(input.get("makeDirs"))) {
                    Files.createDirectories(base.resolve(String.valueOf(item)));
                }
            }
            List<PathChecker.Grant> grants = new ArrayList<>();
            if (input.get("grants") != null) {
                for (Object item : ConformanceUtil.array(input.get("grants"))) {
                    Map<String, Object> grant = ConformanceUtil.object(item);
                    Path root = base.resolve(ConformanceUtil.string(grant, "root"));
                    Files.createDirectories(root);
                    grants.add(new PathChecker.Grant(
                            root.toString(), ConformanceUtil.string(grant, "access")));
                }
            }
            String need = input.get("need") == null
                    ? "read" : ConformanceUtil.string(input, "need");
            Path target = base.resolve(ConformanceUtil.string(input, "target"));
            if (expect.get("error") != null && ConformanceUtil.bool(expect, "error", false)) {
                try {
                    new PathChecker(grants).check(target.toString(), need);
                } catch (PraxoException error) {
                    if (error.code.equals("POLICY_ERROR")) {
                        return;
                    }
                    throw error;
                }
                throw new AssertionError("expected a policy error");
            }
            boolean allowed = new PathChecker(grants)
                    .check(target.toString(), need).allowed();
            ConformanceUtil.check(
                    allowed == ConformanceUtil.bool(expect, "allowed", false),
                    "allowed: got " + allowed);
        } finally {
            ConformanceUtil.deleteRecursively(base);
        }
    }

    private static void runContext(Map<String, Object> vector) {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        List<Message> messages = new ArrayList<>();
        if (input.get("messages") != null) {
            for (Object item : ConformanceUtil.array(input.get("messages"))) {
                messages.add(Message.fromWire(item));
            }
        }
        String operation = ConformanceUtil.string(input, "operation");
        if ("estimate".equals(operation)) {
            int got = Contexts.estimateTokens(messages);
            ConformanceUtil.check(
                    got == ConformanceUtil.integer(expect, "tokens"),
                    "tokens: got " + got);
            return;
        }
        Map<String, Object> budgetInput = ConformanceUtil.object(input.get("budget"));
        ContextBudget budget = new ContextBudget(
                ConformanceUtil.integer(budgetInput, "maxTokens"),
                ConformanceUtil.integer(budgetInput, "keepRecent"));
        ContextBudget.Result result = budget.compact(messages);
        ConformanceUtil.check(
                result.ok() == ConformanceUtil.bool(expect, "ok", false),
                "ok: got " + result.ok());
        if (!result.ok()) {
            return;
        }
        int got = Contexts.estimateTokens(result.messages());
        ConformanceUtil.check(
                got == ConformanceUtil.integer(expect, "tokens"),
                "tokens: got " + got);
        List<Object> wire = new ArrayList<>();
        for (Message message : result.messages()) {
            wire.add(message.toWire());
        }
        ConformanceUtil.check(
                ConformanceUtil.deepEquals(wire, expect.get("messages")),
                "messages: got " + Json.stringify(wire));
    }
}
