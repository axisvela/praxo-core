#ifndef PRAXO_MCP_H
#define PRAXO_MCP_H

#include <stdbool.h>

#include "praxo.h"

typedef PxValue *(*PxMcpTransport)(PxArena *arena, const char *method,
    PxValue *params, void *ctx, const char **error);

typedef struct {
    const char *client_version;
    const char *protocol_version;
    PxValue *server_info;
    PxMcpTransport transport;
    void *ctx;
    bool closed;
} PxMcpClient;

bool px_mcp_client(PxArena *arena, PxMcpTransport transport, void *ctx,
    const char *client_version, const char *protocol_version,
    PxMcpClient *client, const char **error);
PxValue *px_mcp_list_tools(PxArena *arena, PxMcpClient *client,
    const char **error);
PxValue *px_mcp_call_tool(PxArena *arena, PxMcpClient *client, const char *name,
    PxValue *arguments, const char **error);
void px_mcp_close(PxMcpClient *client);

#endif
