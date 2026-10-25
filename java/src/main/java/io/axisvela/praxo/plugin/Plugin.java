package io.axisvela.praxo.plugin;

import io.axisvela.praxo.PraxoException;
import io.axisvela.praxo.util.Json;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

public final class Plugin {
    public static final Set<String> KINDS = Set.of(
            "tool.provider.v1",
            "model.provider.v1",
            "policy.provider.v1",
            "memory.provider.v1",
            "sandbox.provider.v1");

    public static final List<String> STATES = List.of(
            "FETCHED", "VALIDATED", "LOADED", "ACTIVE", "DRAINING",
            "STOPPED", "UNLOADED", "FAILED", "QUARANTINED");

    public static final List<String> EVENT_KINDS = List.of(
            "start", "success", "failure", "stop", "crash",
            "verification_denied", "registration_denied",
            "authorization_denied", "resource_limit", "canceled", "terminated");

    private static final Pattern REVERSE_DNS = Pattern.compile(
            "^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$");
    private static final Pattern SEMVER = Pattern.compile(
            "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?$");
    private static final Pattern ENV_NAME =
            Pattern.compile("^[A-Za-z_][A-Za-z0-9_]*$");

    private static final Set<String> TOP_KEYS = Set.of(
            "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
            "capabilities", "permissions", "limits", "isolation", "health",
            "signature", "sbom");
    private static final Set<String> ENTRYPOINT_KEYS = Set.of(
            "type", "command", "module", "image", "args", "dir");
    private static final Set<String> PERMISSION_KEYS =
            Set.of("filesystem", "network", "env");
    private static final Set<String> FILESYSTEM_KEYS = Set.of("path", "mode");
    private static final Set<String> NETWORK_KEYS = Set.of("host", "port");
    private static final Set<String> LIMIT_KEYS = Set.of(
            "memoryMB", "cpuMillis", "timeoutMs", "maxInflight");
    private static final Set<String> HEALTH_KEYS = Set.of("method", "intervalMs");
    private static final Set<String> SIGNATURE_KEYS = Set.of("algorithm", "keyId");

    private Plugin() {
    }

    public static Manifest parseManifest(String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            throw PraxoException.plugin("plugin: manifest is empty");
        }
        Map<String, Object> value;
        try {
            value = Json.object(raw);
        } catch (RuntimeException error) {
            throw PraxoException.plugin("plugin: manifest: " + error.getMessage());
        }
        checkKeys(value, TOP_KEYS, "manifest");
        int schemaVersion = asInt(value.get("schemaVersion"), "schemaVersion");
        if (schemaVersion != 1) {
            throw PraxoException.plugin(
                    "plugin: manifest: schemaVersion = " + schemaVersion + ", want 1");
        }
        String id = asString(value.get("id"), "id");
        if (!REVERSE_DNS.matcher(id).matches()) {
            throw PraxoException.plugin(
                    "plugin: manifest: id " + id + " is not reverse-DNS");
        }
        String version = asString(value.get("version"), "version");
        if (!SEMVER.matcher(version).matches()) {
            throw PraxoException.plugin(
                    "plugin: manifest: version " + version + " is not semver");
        }
        String kind = asString(value.get("kind"), "kind");
        if (!KINDS.contains(kind)) {
            throw PraxoException.plugin(
                    "plugin: manifest: kind " + kind + " is not a known contract");
        }
        String protocol = asString(value.get("protocol"), "protocol");
        if (!protocol.equals("jsonrpc-2")) {
            throw PraxoException.plugin(
                    "plugin: manifest: protocol = " + protocol + ", want jsonrpc-2");
        }

        Map<String, Object> entrypoint = asObject(value.get("entrypoint"), "entrypoint");
        checkKeys(entrypoint, ENTRYPOINT_KEYS, "entrypoint");
        String entryType = asString(entrypoint.get("type"), "entrypoint.type");
        switch (entryType) {
            case "process" -> {
                if (entrypoint.get("command") == null
                        || entrypoint.get("command").toString().isEmpty()) {
                    throw PraxoException.plugin(
                            "plugin: manifest: process entrypoint requires command");
                }
            }
            case "wasm" -> {
                if (entrypoint.get("module") == null
                        || entrypoint.get("module").toString().isEmpty()) {
                    throw PraxoException.plugin(
                            "plugin: manifest: wasm entrypoint requires module");
                }
            }
            case "container" -> {
                if (entrypoint.get("image") == null
                        || entrypoint.get("image").toString().isEmpty()) {
                    throw PraxoException.plugin(
                            "plugin: manifest: container entrypoint requires image");
                }
            }
            default -> throw PraxoException.plugin(
                    "plugin: manifest: unknown entrypoint type " + entryType);
        }
        String isolation = asString(value.get("isolation"), "isolation");
        if (!isolation.equals(entryType)) {
            throw PraxoException.plugin(
                    "plugin: manifest: isolation " + isolation
                            + " does not match entrypoint " + entryType);
        }

        Map<String, Object> permissions = asObject(value.get("permissions"), "permissions");
        checkKeys(permissions, PERMISSION_KEYS, "permissions");
        validatePermissions(permissions);

        Map<String, Object> limits = asObject(value.get("limits"), "limits");
        checkKeys(limits, LIMIT_KEYS, "limits");
        for (Map.Entry<String, Object> entry : limits.entrySet()) {
            if (asInt(entry.getValue(), "limits." + entry.getKey()) < 0) {
                throw PraxoException.plugin(
                        "plugin: manifest: limits must not be negative");
            }
        }

        Map<String, Object> health = asObject(value.get("health"), "health");
        checkKeys(health, HEALTH_KEYS, "health");
        int interval = health.get("intervalMs") == null
                ? 0 : asInt(health.get("intervalMs"), "health.intervalMs");
        if (interval < 0) {
            throw PraxoException.plugin(
                    "plugin: manifest: health interval must not be negative");
        }
        if (interval > 0 && (health.get("method") == null
                || health.get("method").toString().isEmpty())) {
            throw PraxoException.plugin(
                    "plugin: manifest: health interval requires method");
        }

        Map<String, Object> signature = null;
        if (value.get("signature") != null) {
            signature = asObject(value.get("signature"), "signature");
            checkKeys(signature, SIGNATURE_KEYS, "signature");
            if (signature.get("algorithm") == null
                    || signature.get("keyId") == null) {
                throw PraxoException.plugin(
                        "plugin: manifest: signature requires algorithm and keyId");
            }
        }

        String sbom = value.get("sbom") == null
                ? "" : asString(value.get("sbom"), "sbom");
        if (!sbom.isEmpty()) {
            validateRelativePath(sbom);
        }

        List<String> capabilities = new ArrayList<>();
        if (value.get("capabilities") != null) {
            for (Object item : Json.asArray(value.get("capabilities"))) {
                capabilities.add(asString(item, "capabilities"));
            }
        }
        Set<String> seen = new LinkedHashSet<>();
        for (String capability : capabilities) {
            if (capability.isEmpty()) {
                throw PraxoException.plugin(
                        "plugin: manifest: capability must not be empty");
            }
            if (!seen.add(capability)) {
                throw PraxoException.plugin(
                        "plugin: manifest: duplicate capability " + capability);
            }
        }

        return new Manifest(schemaVersion, id, version, kind, entrypoint,
                protocol, capabilities, permissions, limits, isolation,
                health, signature, sbom);
    }

    public static void validateTrust(Manifest manifest, String profile) {
        if (profile.equals("signed")) {
            if (manifest.signature() == null) {
                throw PraxoException.plugin(
                        "plugin: manifest: signed trust profile requires a signature");
            }
            if (manifest.sbom().isEmpty()) {
                throw PraxoException.plugin(
                        "plugin: manifest: signed trust profile requires an sbom");
            }
            return;
        }
        if (!profile.equals("unsigned")) {
            throw PraxoException.plugin(
                    "plugin: manifest: unknown trust profile " + profile);
        }
    }

    private static void validatePermissions(Map<String, Object> permissions) {
        if (permissions.get("filesystem") != null) {
            for (Object item : Json.asArray(permissions.get("filesystem"))) {
                Map<String, Object> entry = Json.asObject(item);
                checkKeys(entry, FILESYSTEM_KEYS, "filesystem");
                if (entry.get("path") == null
                        || entry.get("path").toString().isEmpty()) {
                    throw PraxoException.plugin(
                            "plugin: manifest: filesystem permission requires path");
                }
                String mode = entry.get("mode") == null
                        ? "" : entry.get("mode").toString();
                if (!mode.equals("read") && !mode.equals("write")
                        && !mode.equals("readwrite")) {
                    throw PraxoException.plugin(
                            "plugin: manifest: filesystem mode " + mode
                                    + " is not read, write, or readwrite");
                }
            }
        }
        if (permissions.get("network") != null) {
            for (Object item : Json.asArray(permissions.get("network"))) {
                Map<String, Object> entry = Json.asObject(item);
                checkKeys(entry, NETWORK_KEYS, "network");
                if (entry.get("host") == null
                        || entry.get("host").toString().isEmpty()) {
                    throw PraxoException.plugin(
                            "plugin: manifest: network permission requires host");
                }
                int port = asInt(entry.get("port"), "permissions.network.port");
                if (port < 1 || port > 65535) {
                    throw PraxoException.plugin(
                            "plugin: manifest: network port " + port + " is out of range");
                }
            }
        }
        if (permissions.get("env") != null) {
            for (Object item : Json.asArray(permissions.get("env"))) {
                String name = asString(item, "permissions.env");
                if (!ENV_NAME.matcher(name).matches()) {
                    throw PraxoException.plugin(
                            "plugin: manifest: env name " + name + " is invalid");
                }
            }
        }
    }

    private static void validateRelativePath(String value) {
        String normalized = value.replace("\\", "/");
        Path path = Paths.get(value);
        if (normalized.startsWith("/") || path.isAbsolute()) {
            throw PraxoException.plugin(
                    "plugin: manifest: sbom path must be relative");
        }
        for (String part : normalized.split("/")) {
            if (part.equals("..")) {
                throw PraxoException.plugin(
                        "plugin: manifest: sbom path must not contain '..'");
            }
        }
    }

    private static void checkKeys(
            Map<String, Object> value, Set<String> allowed, String where) {
        for (String key : value.keySet()) {
            if (!allowed.contains(key)) {
                throw PraxoException.plugin(
                        "plugin: manifest: unknown field " + key + " in " + where);
            }
        }
    }

    private static Map<String, Object> asObject(Object value, String where) {
        if (value == null) {
            return new LinkedHashMap<>();
        }
        if (value instanceof Map<?, ?>) {
            return Json.asObject(value);
        }
        throw PraxoException.plugin(
                "plugin: manifest: " + where + " must be an object");
    }

    private static String asString(Object value, String where) {
        String text = Json.string(value);
        if (text == null) {
            throw PraxoException.plugin(
                    "plugin: manifest: " + where + " must be a string");
        }
        return text;
    }

    private static int asInt(Object value, String where) {
        if (value instanceof Number number) {
            if (number.doubleValue() != Math.rint(number.doubleValue())) {
                throw PraxoException.plugin(
                        "plugin: manifest: " + where + " must be an integer");
            }
            return number.intValue();
        }
        throw PraxoException.plugin(
                "plugin: manifest: " + where + " must be an integer");
    }
}
