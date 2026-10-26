package io.axisvela.praxo.conformance;

import io.axisvela.praxo.Version;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.TreeSet;

public final class ApiSnapshot {
    private ApiSnapshot() {
    }

    public static void main(String[] args) throws Exception {
        Path root = ConformanceUtil.repoRoot();
        boolean check = false;
        Path classes = Path.of("target", "classes");
        for (String arg : args) {
            if (arg.equals("--check")) {
                check = true;
            } else {
                classes = Path.of(arg);
            }
        }
        if (!Files.isDirectory(classes)) {
            classes = Path.of("out");
        }
        Path target = root.resolve("sdk").resolve("java").resolve("api")
                .resolve(Version.SDK_VERSION + ".txt");
        String content = snapshot(root, classes);
        if (check) {
            if (!Files.exists(target)) {
                System.err.println("missing snapshot: " + target);
                System.exit(1);
            }
            if (!Files.readString(target, StandardCharsets.UTF_8).equals(content)) {
                System.err.println("snapshot is stale: " + target);
                System.exit(1);
            }
            System.out.println("snapshot is current: " + target);
            return;
        }
        Files.createDirectories(target.getParent());
        Files.writeString(target, content, StandardCharsets.UTF_8);
        System.out.println("wrote " + target);
    }

    private static String snapshot(Path root, Path classes) throws Exception {
        List<Path> files;
        try (var stream = Files.walk(classes)) {
            files = stream.filter(path -> path.toString().endsWith(".class"))
                    .sorted(Comparator.comparing(Path::toString))
                    .toList();
        }
        TreeSet<String> lines = new TreeSet<>();
        ClassLoader loader = ApiSnapshot.class.getClassLoader();
        for (Path file : files) {
            String relative = classes.relativize(file).toString()
                    .replace('\\', '/')
                    .replace('/', '.')
                    .replaceAll("\\.class$", "");
            if (relative.equals("module-info")
                    || relative.equals("package-info")
                    || relative.startsWith("io.axisvela.praxo.conformance.")) {
                continue;
            }
            Class<?> type;
            try {
                type = Class.forName(relative, false, loader);
            } catch (ClassNotFoundException | LinkageError error) {
                continue;
            }
            if (!Modifier.isPublic(type.getModifiers())) {
                continue;
            }
            String display = type.getName()
                    .replace("io.axisvela.praxo.", "")
                    .replace('$', '.');
            lines.add(display);
            for (Method method : type.getDeclaredMethods()) {
                if (Modifier.isPublic(method.getModifiers())
                        && !method.isSynthetic()
                        && !method.isBridge()) {
                    lines.add(display + "." + method.getName());
                }
            }
            for (Field field : type.getDeclaredFields()) {
                if (Modifier.isPublic(field.getModifiers())
                        && !field.isSynthetic()) {
                    lines.add(display + "." + field.getName());
                }
            }
        }
        String specVersion = Files.readString(
                root.resolve("spec").resolve("SPEC_VERSION"),
                StandardCharsets.UTF_8).trim();
        List<String> out = new ArrayList<>();
        out.add("# PRAXO-CORE Java API " + Version.SDK_VERSION);
        out.add("# SPEC_VERSION " + specVersion);
        out.add("");
        out.addAll(lines);
        return String.join("\n", out) + "\n";
    }
}
