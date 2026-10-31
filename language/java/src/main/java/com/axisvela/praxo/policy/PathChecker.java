package com.axisvela.praxo.policy;

import com.axisvela.praxo.PraxoException;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public final class PathChecker {
    public record Grant(String root, String access) {
    }

    private static final Set<String> ACCESS = Set.of("read", "write", "readwrite");
    private final List<Grant> grants;

    public PathChecker(List<Grant> grants) {
        List<Grant> resolved = new ArrayList<>();
        for (Grant grant : grants) {
            if (grant.root() == null || grant.root().isEmpty()) {
                throw PraxoException.policy("policy: path grant root is required");
            }
            if (!ACCESS.contains(grant.access())) {
                throw PraxoException.policy(
                        "policy: invalid grant access " + grant.access());
            }
            resolved.add(new Grant(resolve(grant.root()), grant.access()));
        }
        this.grants = List.copyOf(resolved);
    }

    public Decision check(String target, String need) {
        if (!ACCESS.contains(need)) {
            throw PraxoException.policy(
                    "policy: invalid requested access " + need);
        }
        if (grants.isEmpty()) {
            return Decision.deny("no allowed roots");
        }
        String resolved = resolve(target);
        String matched = "";
        for (Grant grant : grants) {
            if (!within(grant.root(), resolved)) {
                continue;
            }
            matched = grant.root();
            if (allows(grant.access(), need)) {
                return Decision.allow("path within " + grant.root());
            }
        }
        if (!matched.isEmpty()) {
            return Decision.deny(
                    "path within " + matched + " but the grant is insufficient");
        }
        return Decision.deny("path outside allowed roots");
    }

    public boolean allowed(String target, String need) {
        try {
            return check(target, need).allowed();
        } catch (PraxoException error) {
            return false;
        }
    }

    private static String resolve(String value) {
        Path absolute;
        try {
            absolute = Paths.get(value).toAbsolutePath().normalize();
        } catch (RuntimeException error) {
            throw PraxoException.policy(
                    "policy: resolve " + value + ": " + error);
        }
        try {
            return absolute.toRealPath().toString();
        } catch (NoSuchFileException ignored) {
            // resolve the nearest existing ancestor
        } catch (IOException error) {
            throw PraxoException.policy(
                    "policy: resolve " + value + ": " + error);
        }
        Path current = absolute;
        List<String> suffix = new ArrayList<>();
        while (true) {
            Path parent = current.getParent();
            if (parent == null) {
                return absolute.toString();
            }
            suffix.add(0, current.getFileName().toString());
            current = parent;
            try {
                Path real = current.toRealPath();
                Path resolved = real;
                for (String part : suffix) {
                    resolved = resolved.resolve(part);
                }
                return resolved.toString();
            } catch (NoSuchFileException ignored) {
                // keep walking up
            } catch (IOException error) {
                throw PraxoException.policy(
                        "policy: resolve " + value + ": " + error);
            }
        }
    }

    private static boolean within(String root, String target) {
        String rootValue = normalize(root);
        String targetValue = normalize(target);
        return rootValue.equals(targetValue)
                || targetValue.startsWith(rootValue + File.separator);
    }

    private static String normalize(String value) {
        String normalized = Paths.get(value).normalize().toString();
        return System.getProperty("os.name").toLowerCase(Locale.ROOT)
                .contains("win")
                ? normalized.toLowerCase(Locale.ROOT)
                : normalized;
    }

    private static boolean allows(String grant, String need) {
        return switch (need) {
            case "read" -> grant.equals("read") || grant.equals("readwrite");
            case "write" -> grant.equals("write") || grant.equals("readwrite");
            default -> grant.equals("readwrite");
        };
    }
}
