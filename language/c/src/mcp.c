#include "mcp.h"

#include <string.h>

static PxValue *transport_failure(const char **error, const char *fallback) {
    if (error != NULL) {
        *error = fallback;
    }
    return NULL;
}

static bool set_error(const char **error, const char *code) {
    if (error != NULL) {
        *error = code;
    }
    return false;
}

static const char **append_string(PxArena *arena, const char **items,
        size_t length, const char *value) {
    const char **grown = px_arena_alloc(arena,
        (length + 1) * sizeof(const char *));
    if (grown == NULL) {
        return NULL;
    }
    if (length > 0) {
        memcpy(grown, items, length * sizeof(const char *));
    }
    grown[length] = value;
    return grown;
}

bool px_mcp_client(PxArena *arena, PxMcpTransport transport, void *ctx,
        const char *client_version, const char *protocol_version,
        PxMcpClient *client, const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    if (arena == NULL || transport == NULL || client == NULL) {
        return set_error(error, "MCP_TRANSPORT");
    }
    const char *version = client_version;
    if (version == NULL || version[0] == '\0') {
        version = PRAXO_SDK_VERSION;
    }
    const char *protocol = protocol_version;
    if (protocol == NULL || protocol[0] == '\0') {
        protocol = "2024-11-05";
    }
    PxValue *params = px_obj(arena);
    px_obj_set(arena, params, "protocolVersion", px_str(arena, protocol));
    px_obj_set(arena, params, "capabilities", px_obj(arena));
    PxValue *info = px_obj(arena);
    px_obj_set(arena, info, "name", px_str(arena, "praxo-core"));
    px_obj_set(arena, info, "version", px_str(arena, version));
    px_obj_set(arena, params, "clientInfo", info);
    const char *transport_error = NULL;
    PxValue *result = transport(arena, "initialize", params, ctx,
        &transport_error);
    if (result == NULL) {
        return set_error(error, transport_error == NULL
            ? "MCP_TRANSPORT" : transport_error);
    }
    if (result->type != PX_OBJ) {
        return set_error(error, "MCP_PROTOCOL");
    }
    const char *negotiated = px_get_str(result, "protocolVersion");
    if (negotiated == NULL || negotiated[0] == '\0') {
        return set_error(error, "MCP_HANDSHAKE");
    }
    PxValue *server = px_obj_get(result, "serverInfo");
    client->client_version = version;
    client->protocol_version = px_arena_strdup(arena, negotiated);
    client->server_info = server != NULL && server->type == PX_OBJ
        ? server : px_obj(arena);
    client->transport = transport;
    client->ctx = ctx;
    client->closed = false;
    return true;
}

PxValue *px_mcp_list_tools(PxArena *arena, PxMcpClient *client,
        const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    if (arena == NULL || client == NULL || client->transport == NULL) {
        return transport_failure(error, "MCP_PROTOCOL");
    }
    PxValue *tools = px_arr(arena);
    const char **names = NULL;
    size_t names_len = 0;
    const char **cursors = NULL;
    size_t cursors_len = 0;
    const char *cursor = "";
    for (;;) {
        PxValue *params = px_obj(arena);
        if (cursor[0] != '\0') {
            px_obj_set(arena, params, "cursor", px_str(arena, cursor));
        }
        const char *transport_error = NULL;
        PxValue *result = client->transport(arena, "tools/list", params,
            client->ctx, &transport_error);
        if (result == NULL) {
            return transport_failure(error, transport_error == NULL
                ? "MCP_TRANSPORT" : transport_error);
        }
        if (result->type != PX_OBJ) {
            return transport_failure(error, "MCP_PROTOCOL");
        }
        PxValue *items = px_obj_get(result, "tools");
        if (items == NULL || items->type != PX_ARR) {
            return transport_failure(error, "MCP_PROTOCOL");
        }
        for (size_t index = 0; index < items->as.array.len; index++) {
            PxValue *item = items->as.array.items[index];
            if (item == NULL || item->type != PX_OBJ) {
                return transport_failure(error, "MCP_PROTOCOL");
            }
            const char *name = px_get_str(item, "name");
            if (name == NULL || name[0] == '\0') {
                return transport_failure(error, "MCP_PROTOCOL");
            }
            for (size_t previous = 0; previous < names_len; previous++) {
                if (strcmp(names[previous], name) == 0) {
                    return transport_failure(error, "MCP_DUPLICATE_TOOL");
                }
            }
            const char **grown = append_string(arena, names, names_len, name);
            if (grown == NULL) {
                return transport_failure(error, "MCP_PROTOCOL");
            }
            names = grown;
            names_len += 1;
            px_arr_push(arena, tools, item);
        }
        PxValue *next = px_obj_get(result, "nextCursor");
        if (next == NULL) {
            break;
        }
        if (next->type != PX_STR) {
            return transport_failure(error, "MCP_PROTOCOL");
        }
        if (next->as.string[0] == '\0') {
            break;
        }
        for (size_t previous = 0; previous < cursors_len; previous++) {
            if (strcmp(cursors[previous], next->as.string) == 0) {
                return transport_failure(error, "MCP_PAGINATION");
            }
        }
        const char **grown = append_string(arena, cursors, cursors_len,
            next->as.string);
        if (grown == NULL) {
            return transport_failure(error, "MCP_PROTOCOL");
        }
        cursors = grown;
        cursors_len += 1;
        cursor = next->as.string;
    }
    return tools;
}

PxValue *px_mcp_call_tool(PxArena *arena, PxMcpClient *client, const char *name,
        PxValue *arguments, const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    if (arena == NULL || client == NULL || client->transport == NULL ||
            name == NULL || name[0] == '\0') {
        return transport_failure(error, "MCP_PROTOCOL");
    }
    PxValue *params = px_obj(arena);
    px_obj_set(arena, params, "name", px_str(arena, name));
    px_obj_set(arena, params, "arguments",
        arguments == NULL ? px_obj(arena) : arguments);
    const char *transport_error = NULL;
    PxValue *result = client->transport(arena, "tools/call", params,
        client->ctx, &transport_error);
    if (result == NULL) {
        return transport_failure(error, transport_error == NULL
            ? "MCP_TRANSPORT" : transport_error);
    }
    if (result->type != PX_OBJ) {
        return transport_failure(error, "MCP_PROTOCOL");
    }
    PxValue *failed = px_obj_get(result, "isError");
    if (failed != NULL && failed->type == PX_BOOL && failed->as.boolean) {
        return transport_failure(error, "MCP_TOOL_ERROR");
    }
    PxValue *structured = px_obj_get(result, "structuredContent");
    if (structured != NULL) {
        return structured;
    }
    PxValue *texts = px_arr(arena);
    PxValue *content = px_obj_get(result, "content");
    if (content != NULL && content->type == PX_ARR) {
        for (size_t index = 0; index < content->as.array.len; index++) {
            PxValue *item = content->as.array.items[index];
            if (item == NULL || item->type != PX_OBJ) {
                continue;
            }
            const char *kind = px_get_str(item, "type");
            const char *text = px_get_str(item, "text");
            if (kind != NULL && strcmp(kind, "text") == 0 && text != NULL) {
                px_arr_push(arena, texts, px_str(arena, text));
            }
        }
    }
    if (texts->as.array.len == 0) {
        return px_null(arena);
    }
    if (texts->as.array.len == 1) {
        return texts->as.array.items[0];
    }
    return texts;
}

void px_mcp_close(PxMcpClient *client) {
    if (client != NULL) {
        client->closed = true;
    }
}
