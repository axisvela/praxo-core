#include "mcp.h"

#include <assert.h>
#include <string.h>

enum Mode {
    MODE_OK,
    MODE_DUPLICATE,
    MODE_REPEATED_CURSOR,
    MODE_TOOL_ERROR,
    MODE_STRUCTURED
};

typedef struct {
    enum Mode mode;
} Fake;

static PxValue *fake_transport(PxArena *arena, const char *method,
        PxValue *params, void *ctx, const char **error) {
    Fake *fake = (Fake *)ctx;
    if (error != NULL) {
        *error = NULL;
    }
    if (strcmp(method, "initialize") == 0) {
        return px_parse(arena,
            "{\"protocolVersion\":\"2024-11-05\","
            "\"serverInfo\":{\"name\":\"fake\"}}");
    }
    if (strcmp(method, "tools/list") == 0) {
        if (fake->mode == MODE_DUPLICATE) {
            return px_parse(arena,
                "{\"tools\":[{\"name\":\"echo\"},{\"name\":\"echo\"}]}");
        }
        if (fake->mode == MODE_REPEATED_CURSOR) {
            return px_parse(arena,
                "{\"tools\":[],\"nextCursor\":\"c1\"}");
        }
        const char *cursor = px_get_str(params, "cursor");
        if (cursor != NULL && strcmp(cursor, "c1") == 0) {
            return px_parse(arena, "{\"tools\":[{\"name\":\"two\"}]}");
        }
        return px_parse(arena,
            "{\"tools\":[{\"name\":\"echo\",\"description\":\"Echo\"}],"
            "\"nextCursor\":\"c1\"}");
    }
    if (strcmp(method, "tools/call") == 0) {
        if (fake->mode == MODE_TOOL_ERROR) {
            return px_parse(arena, "{\"isError\":true}");
        }
        if (fake->mode == MODE_STRUCTURED) {
            return px_parse(arena,
                "{\"structuredContent\":{\"ok\":true}}");
        }
        return px_parse(arena,
            "{\"content\":[{\"type\":\"text\",\"text\":\"ok\"}]}");
    }
    return px_parse(arena, "{}");
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    Fake fake;
    fake.mode = MODE_OK;
    PxMcpClient client;
    const char *error = NULL;
    assert(px_mcp_client(&arena, fake_transport, &fake, "", "", &client,
        &error));
    assert(error == NULL);
    assert(strcmp(client.protocol_version, "2024-11-05") == 0);

    PxValue *tools = px_mcp_list_tools(&arena, &client, &error);
    assert(tools != NULL && tools->type == PX_ARR);
    assert(tools->as.array.len == 2);
    assert(strcmp(px_get_str(tools->as.array.items[0], "name"), "echo") == 0);
    assert(strcmp(px_get_str(tools->as.array.items[1], "name"), "two") == 0);

    PxValue *value = px_mcp_call_tool(&arena, &client, "echo", px_obj(&arena),
        &error);
    assert(value != NULL && value->type == PX_STR);
    assert(strcmp(value->as.string, "ok") == 0);

    fake.mode = MODE_STRUCTURED;
    PxValue *structured = px_mcp_call_tool(&arena, &client, "echo",
        px_obj(&arena), &error);
    assert(structured != NULL && structured->type == PX_OBJ);
    assert(px_get_bool(structured, "ok", false));

    fake.mode = MODE_DUPLICATE;
    assert(px_mcp_list_tools(&arena, &client, &error) == NULL);
    assert(strcmp(error, "MCP_DUPLICATE_TOOL") == 0);

    fake.mode = MODE_REPEATED_CURSOR;
    assert(px_mcp_list_tools(&arena, &client, &error) == NULL);
    assert(strcmp(error, "MCP_PAGINATION") == 0);

    fake.mode = MODE_TOOL_ERROR;
    assert(px_mcp_call_tool(&arena, &client, "echo", px_obj(&arena),
        &error) == NULL);
    assert(strcmp(error, "MCP_TOOL_ERROR") == 0);

    px_mcp_close(&client);
    assert(client.closed);
    px_arena_free(&arena);
    return 0;
}
