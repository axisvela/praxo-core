package io.axisvela.praxo.plugin;

import java.util.List;
import java.util.Map;

public record Manifest(
        int schemaVersion,
        String id,
        String version,
        String kind,
        Map<String, Object> entrypoint,
        String protocol,
        List<String> capabilities,
        Map<String, Object> permissions,
        Map<String, Object> limits,
        String isolation,
        Map<String, Object> health,
        Map<String, Object> signature,
        String sbom) {
}
