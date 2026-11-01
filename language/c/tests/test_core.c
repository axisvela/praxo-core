#include "jsonschema.h"
#include "plugin.h"
#include "praxo.h"
#include "toolcall.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    PxValue *object = px_parse(&arena, "{\"a\":1}");
    assert(object != NULL);
    assert(object->type == PX_OBJ);
    assert(px_get_num(object, "a", 0) == 1);

    PxToolCall *call = px_parse_toolcall(
        &arena, "<echo.echo>{\"text\":\"hi\"}</echo.echo>");
    assert(call != NULL);
    assert(strcmp(call->name, "echo.echo") == 0);
    assert(strcmp(px_get_str(call->input, "text"), "hi") == 0);

    PxValue *schema = px_parse(
        &arena,
        "{\"type\":\"object\",\"required\":[\"name\"]}");
    PxValue *data = px_parse(&arena, "{\"name\":\"ok\"}");
    PxValue *errors = px_arr(&arena);
    px_schema_validate(&arena, schema, data, "$", errors);
    assert(errors->as.array.len == 0);

    PxValue *integer = px_parse(&arena, "{\"type\":\"integer\"}");
    PxValue *integer_errors = px_arr(&arena);
    px_schema_validate(&arena, integer, px_parse(&arena, "2.5"), "$", integer_errors);
    assert(integer_errors->as.array.len == 1);
    PxValue *unicode_schema = px_parse(&arena, "{\"type\":\"string\",\"minLength\":2,\"maxLength\":2}");
    PxValue *unicode_errors = px_arr(&arena);
    px_schema_validate(&arena, unicode_schema, px_str(&arena, "你好"), "$", unicode_errors);
    assert(unicode_errors->as.array.len == 0);
    PxValue *short_errors = px_arr(&arena);
    px_schema_validate(&arena, unicode_schema, px_str(&arena, "你"), "$", short_errors);
    assert(short_errors->as.array.len == 1);

    PxValue *manifest = px_parse(
        &arena,
        "{\"schemaVersion\":1,\"id\":\"com.example.echo\","
        "\"version\":\"1.0.0\",\"kind\":\"tool.provider.v1\","
        "\"entrypoint\":{\"type\":\"process\",\"command\":\"echo\"},"
        "\"protocol\":\"jsonrpc-2\",\"capabilities\":[],"
        "\"permissions\":{},\"limits\":{},\"health\":{},"
        "\"isolation\":\"process\"}");
    const char *id = NULL;
    const char *kind = NULL;
    assert(px_plugin_validate(manifest, &id, &kind));
    assert(strcmp(id, "com.example.echo") == 0);

    px_arena_free(&arena);
    printf("C core tests passed\n");
    return 0;
}
