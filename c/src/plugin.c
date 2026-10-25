#include "plugin.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

static bool key_allowed(
    const char *key, const char *const *allowed, size_t count) {
    for (size_t index = 0; index < count; index++) {
        if (strcmp(key, allowed[index]) == 0) {
            return true;
        }
    }
    return false;
}

static bool keys_allowed(
    PxValue *object, const char *const *allowed, size_t count) {
    if (object == NULL || object->type != PX_OBJ) {
        return false;
    }
    for (size_t index = 0; index < object->as.object.len; index++) {
        if (!key_allowed(object->as.object.pairs[index].key, allowed, count)) {
            return false;
        }
    }
    return true;
}

static bool reverse_dns(const char *text) {
    bool label = false;
    bool dot = false;
    for (const char *cursor = text; *cursor != '\0'; cursor++) {
        if (*cursor == '.') {
            if (!label) {
                return false;
            }
            label = false;
            dot = true;
        } else if (isalnum((unsigned char)*cursor) || *cursor == '-') {
            label = true;
        } else {
            return false;
        }
    }
    return label && dot;
}

static bool semver(const char *text) {
    int parts = 0;
    const char *cursor = text;
    while (parts < 3) {
        const char *start = cursor;
        while (isdigit((unsigned char)*cursor)) {
            cursor++;
        }
        if (cursor == start) {
            return false;
        }
        parts++;
        if (parts < 3) {
            if (*cursor != '.') {
                return false;
            }
            cursor++;
        }
    }
    return *cursor == '\0';
}

static bool env_name(const char *text) {
    if (!(isalpha((unsigned char)*text) || *text == '_')) {
        return false;
    }
    for (const char *cursor = text + 1; *cursor != '\0'; cursor++) {
        if (!(isalnum((unsigned char)*cursor) || *cursor == '_')) {
            return false;
        }
    }
    return true;
}

static bool relative_path(const char *text) {
    if (text[0] == '/' || text[0] == '\\') {
        return false;
    }
    if (isalpha((unsigned char)text[0]) && text[1] == ':') {
        return false;
    }
    const char *cursor = text;
    while (*cursor != '\0') {
        if (cursor[0] == '.' && cursor[1] == '.'
                && (cursor[2] == '/' || cursor[2] == '\\' || cursor[2] == '\0')) {
            return false;
        }
        cursor++;
    }
    return true;
}

static bool permissions_valid(PxValue *permissions) {
    static const char *const keys[] = {"filesystem", "network", "env"};
    if (permissions == NULL) {
        return true;
    }
    if (!keys_allowed(permissions, keys, 3)) {
        return false;
    }
    PxValue *filesystem = px_obj_get(permissions, "filesystem");
    if (filesystem != NULL) {
        if (filesystem->type != PX_ARR) {
            return false;
        }
        for (size_t index = 0; index < filesystem->as.array.len; index++) {
            static const char *const item_keys[] = {"path", "mode"};
            PxValue *item = filesystem->as.array.items[index];
            if (!keys_allowed(item, item_keys, 2)) {
                return false;
            }
            const char *path = px_get_str(item, "path");
            const char *mode = px_get_str(item, "mode");
            if (path == NULL || path[0] == '\0' || mode == NULL) {
                return false;
            }
            if (strcmp(mode, "read") != 0 && strcmp(mode, "write") != 0
                    && strcmp(mode, "readwrite") != 0) {
                return false;
            }
        }
    }
    PxValue *network = px_obj_get(permissions, "network");
    if (network != NULL) {
        if (network->type != PX_ARR) {
            return false;
        }
        for (size_t index = 0; index < network->as.array.len; index++) {
            static const char *const item_keys[] = {"host", "port"};
            PxValue *item = network->as.array.items[index];
            if (!keys_allowed(item, item_keys, 2)) {
                return false;
            }
            if (px_get_str(item, "host") == NULL) {
                return false;
            }
            double port = px_get_num(item, "port", 0);
            if (port < 1 || port > 65535) {
                return false;
            }
        }
    }
    PxValue *env = px_obj_get(permissions, "env");
    if (env != NULL) {
        if (env->type != PX_ARR) {
            return false;
        }
        for (size_t index = 0; index < env->as.array.len; index++) {
            if (env->as.array.items[index]->type != PX_STR
                    || !env_name(env->as.array.items[index]->as.string)) {
                return false;
            }
        }
    }
    return true;
}

bool px_plugin_validate(
    PxValue *manifest, const char **id, const char **kind) {
    static const char *const top_keys[] = {
        "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
        "capabilities", "permissions", "limits", "isolation", "health",
        "signature", "sbom"};
    static const char *const entry_keys[] = {
        "type", "command", "module", "image", "args", "dir"};
    static const char *const limit_keys[] = {
        "memoryMB", "cpuMillis", "timeoutMs", "maxInflight"};
    static const char *const health_keys[] = {"method", "intervalMs"};
    static const char *const signature_keys[] = {"algorithm", "keyId"};
    if (manifest == NULL || manifest->type != PX_OBJ) {
        return false;
    }
    if (!keys_allowed(manifest, top_keys, 13)) {
        return false;
    }
    if (px_get_num(manifest, "schemaVersion", 0) != 1) {
        return false;
    }
    *id = px_get_str(manifest, "id");
    *kind = px_get_str(manifest, "kind");
    const char *version = px_get_str(manifest, "version");
    const char *protocol = px_get_str(manifest, "protocol");
    if (*id == NULL || !reverse_dns(*id)) {
        return false;
    }
    if (version == NULL || !semver(version)) {
        return false;
    }
    if (*kind == NULL
            || (strcmp(*kind, "tool.provider.v1") != 0
                && strcmp(*kind, "model.provider.v1") != 0
                && strcmp(*kind, "policy.provider.v1") != 0
                && strcmp(*kind, "memory.provider.v1") != 0
                && strcmp(*kind, "sandbox.provider.v1") != 0)) {
        return false;
    }
    if (protocol == NULL || strcmp(protocol, "jsonrpc-2") != 0) {
        return false;
    }
    PxValue *entrypoint = px_obj_get(manifest, "entrypoint");
    if (entrypoint == NULL || entrypoint->type != PX_OBJ
            || !keys_allowed(entrypoint, entry_keys, 6)) {
        return false;
    }
    const char *entry_type = px_get_str(entrypoint, "type");
    if (entry_type == NULL) {
        return false;
    }
    if (strcmp(entry_type, "process") == 0) {
        if (px_get_str(entrypoint, "command") == NULL) {
            return false;
        }
    } else if (strcmp(entry_type, "wasm") == 0) {
        if (px_get_str(entrypoint, "module") == NULL) {
            return false;
        }
    } else if (strcmp(entry_type, "container") == 0) {
        if (px_get_str(entrypoint, "image") == NULL) {
            return false;
        }
    } else {
        return false;
    }
    const char *isolation = px_get_str(manifest, "isolation");
    if (isolation == NULL || strcmp(isolation, entry_type) != 0) {
        return false;
    }
    if (!permissions_valid(px_obj_get(manifest, "permissions"))) {
        return false;
    }
    PxValue *limits = px_obj_get(manifest, "limits");
    if (limits != NULL) {
        if (limits->type != PX_OBJ || !keys_allowed(limits, limit_keys, 4)) {
            return false;
        }
        for (size_t index = 0; index < limits->as.object.len; index++) {
            PxValue *value = limits->as.object.pairs[index].value;
            if (value->type != PX_NUM || value->as.number < 0) {
                return false;
            }
        }
    }
    PxValue *health = px_obj_get(manifest, "health");
    if (health != NULL) {
        if (health->type != PX_OBJ || !keys_allowed(health, health_keys, 2)) {
            return false;
        }
        double interval = px_get_num(health, "intervalMs", 0);
        if (interval < 0) {
            return false;
        }
        if (interval > 0 && px_get_str(health, "method") == NULL) {
            return false;
        }
    }
    PxValue *signature = px_obj_get(manifest, "signature");
    if (signature != NULL) {
        if (signature->type != PX_OBJ
                || !keys_allowed(signature, signature_keys, 2)
                || px_get_str(signature, "algorithm") == NULL
                || px_get_str(signature, "keyId") == NULL) {
            return false;
        }
    }
    const char *sbom = px_get_str(manifest, "sbom");
    if (sbom != NULL && sbom[0] != '\0' && !relative_path(sbom)) {
        return false;
    }
    PxValue *capabilities = px_obj_get(manifest, "capabilities");
    if (capabilities != NULL) {
        if (capabilities->type != PX_ARR) {
            return false;
        }
        for (size_t index = 0; index < capabilities->as.array.len; index++) {
            PxValue *item = capabilities->as.array.items[index];
            if (item->type != PX_STR || item->as.string[0] == '\0') {
                return false;
            }
            for (size_t other = index + 1; other < capabilities->as.array.len; other++) {
                if (strcmp(item->as.string,
                           capabilities->as.array.items[other]->as.string) == 0) {
                    return false;
                }
            }
        }
    }
    return true;
}
