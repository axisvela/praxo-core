package io.axisvela.praxo.conformance;

import io.axisvela.praxo.Version;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

final class Parity {
    private Parity() {
    }

    static List<String> check() throws Exception {
        Path root = ConformanceUtil.repoRoot();
        Path snapshotPath = root.resolve("sdk").resolve("java").resolve("api")
                .resolve(Version.SDK_VERSION + ".txt");
        if (!Files.exists(snapshotPath)) {
            return List.of("missing API snapshot: " + snapshotPath);
        }
        Set<String> names = new HashSet<>();
        for (String line : Files.readString(snapshotPath, StandardCharsets.UTF_8)
                .split("\n")) {
            String trimmed = line.trim();
            if (!trimmed.isEmpty() && !trimmed.startsWith("#")) {
                names.add(trimmed);
            }
        }
        String parity = Files.readString(
                root.resolve("spec").resolve("parity.md"),
                StandardCharsets.UTF_8);
        Map<String, String> statuses = new HashMap<>();
        for (String line : parity.split("\n")) {
            String trimmed = line.trim();
            if (!trimmed.startsWith("| `pkg/")) {
                continue;
            }
            String[] cells = trimmed.split("\\|");
            if (cells.length < 7) {
                continue;
            }
            statuses.put(strip(cells[1]), strip(cells[5]));
        }
        List<String> failures = new ArrayList<>();
        for (String line : parity.split("\n")) {
            String trimmed = line.trim();
            if (!trimmed.startsWith("| `") || trimmed.startsWith("| `pkg/")) {
                continue;
            }
            String[] cells = trimmed.split("\\|");
            if (cells.length < 7) {
                continue;
            }
            String goSymbol = strip(cells[1]);
            String javaSymbol = strip(cells[5]);
            int dot = goSymbol.lastIndexOf('.');
            if (dot < 0) {
                continue;
            }
            String prefix = goSymbol.substring(0, dot);
            String pkg = prefix.startsWith("pkg/") ? prefix : "pkg/" + prefix;
            if (!"parity".equals(statuses.get(pkg))) {
                continue;
            }
            if (!present(names, javaSymbol)) {
                failures.add(goSymbol + ": missing " + javaSymbol);
            }
        }
        return failures;
    }

    private static boolean present(Set<String> names, String symbol) {
        if (names.contains(symbol)) {
            return true;
        }
        String suffix = "." + symbol;
        for (String name : names) {
            if (name.endsWith(suffix)) {
                return true;
            }
        }
        return false;
    }

    private static String strip(String value) {
        return value == null ? "" : value.trim().replaceAll("^`|`$", "");
    }
}
