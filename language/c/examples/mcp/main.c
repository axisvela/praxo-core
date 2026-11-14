#include "mcp.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static PxValue *transport(PxArena *arena, const char *method,
        PxValue *params, void *ctx, const char **error) {
    (void)params;
    (void)ctx;
    *error = NULL;
    if (strcmp(method, "initialize") == 0) {
        return px_parse(arena,
            "{\"protocolVersion\":\"2024-11-05\","
            "\"serverInfo\":{\"name\":\"example-mcp\",\"version\":\"1.0.0\"}}");
    }
    if (strcmp(method, "tools/list") == 0) {
        return px_parse(arena,
            "{\"tools\":[{\"name\":\"echo\",\"description\":\"Echo input\"},"
            "{\"name\":\"add\",\"description\":\"Add two integers\"}]}");
    }
    if (strcmp(method, "tools/call") == 0) {
        return px_parse(arena, "{\"structuredContent\":{\"sum\":5}}");
    }
    *error = "MCP_RPC";
    return NULL;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxMcpClient client;
    const char *error = NULL;
    assert(px_mcp_client(&arena, transport, NULL, "", "", &client, &error));
    assert(error == NULL);

    PxValue *tools = px_mcp_list_tools(&arena, &client, &error);
    assert(tools != NULL && tools->type == PX_ARR && tools->as.array.len == 2);
    assert(strcmp(px_get_str(tools->as.array.items[0], "name"), "echo") == 0);
    assert(strcmp(px_get_str(tools->as.array.items[1], "name"), "add") == 0);

    PxValue *value = px_mcp_call_tool(&arena, &client, "add", px_obj(&arena),
        &error);
    assert(value != NULL && px_get_num(value, "sum", 0) == 5);

    px_mcp_close(&client);
    px_arena_free(&arena);
    printf("C MCP example passed\n");
    return 0;
}
