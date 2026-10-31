package com.axisvela.praxo.conformance;

import com.axisvela.praxo.event.Event;
import com.axisvela.praxo.event.Sink;
import com.axisvela.praxo.util.Json;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;

final class ConformanceUtil {
    private ConformanceUtil() {
    }

    static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }

    static boolean deepEquals(Object left, Object right) {
        if (left == null || right == null) {
            return left == right;
        }
        if (left instanceof Number a && right instanceof Number b) {
            return Double.compare(a.doubleValue(), b.doubleValue()) == 0;
        }
        if (left instanceof Map<?, ?> a && right instanceof Map<?, ?> b) {
            if (!a.keySet().equals(b.keySet())) {
                return false;
            }
            for (Object key : a.keySet()) {
                if (!deepEquals(a.get(key), b.get(key))) {
                    return false;
                }
            }
            return true;
        }
        if (left instanceof List<?> a && right instanceof List<?> b) {
            if (a.size() != b.size()) {
                return false;
            }
            for (int index = 0; index < a.size(); index++) {
                if (!deepEquals(a.get(index), b.get(index))) {
                    return false;
                }
            }
            return true;
        }
        return Objects.equals(left, right);
    }

    static Path repoRoot() {
        Path current = Path.of("").toAbsolutePath();
        while (current != null) {
            if (Files.exists(current.resolve("spec").resolve("SPEC_VERSION"))) {
                return current;
            }
            current = current.getParent();
        }
        throw new IllegalStateException("repository root not found");
    }

    static List<Path> vectorFiles(Path root) throws IOException {
        Path vectors = root.resolve("spec").resolve("vectors");
        try (var stream = Files.list(vectors)) {
            return stream
                    .filter(path -> path.getFileName().toString().endsWith(".json"))
                    .sorted(Comparator.comparing(path -> path.getFileName().toString()))
                    .toList();
        }
    }

    static String readString(Path path) throws IOException {
        return Files.readString(path);
    }

    static Map<String, Object> object(Object value) {
        return Json.asObject(value);
    }

    static List<Object> array(Object value) {
        return Json.asArray(value);
    }

    static String string(Object value) {
        return Json.string(value);
    }

    static String string(Object map, String key) {
        return Json.string(Json.asObject(map).get(key));
    }

    static int integer(Object map, String key) {
        return Json.intValue(Json.asObject(map).get(key));
    }

    static boolean bool(Object map, String key, boolean fallback) {
        Object value = Json.asObject(map).get(key);
        return value == null ? fallback : Json.bool(value);
    }

    static Object field(Object map, String key) {
        return Json.asObject(map).get(key);
    }

    static void deleteRecursively(Path path) {
        try (var stream = Files.walk(path)) {
            stream.sorted(Comparator.reverseOrder()).forEach(item -> {
                try {
                    Files.deleteIfExists(item);
                } catch (IOException ignored) {
                }
            });
        } catch (IOException ignored) {
        }
    }

    static final class RecordingSink implements Sink {
        final List<String> types = new ArrayList<>();

        @Override
        public void emit(Event event) {
            types.add(event.type());
        }
    }
}
