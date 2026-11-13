function test_mcp()
client = praxo.mcp_client(@transport_ok);
assert(strcmp(client.client_version, '0.5.0'));
assert(strcmp(client.protocol_version, '2024-11-05'));
tools = praxo.mcp_list_tools(client);
assert(numel(tools) == 1);
[name, found] = praxo.json_field(tools{1}, 'name');
assert(found && strcmp(name.value, 'echo'));
value = praxo.mcp_call_tool(client, 'echo', praxo.json_make_object(cell(0, 2)));
assert(strcmp(value.kind, 'string') && strcmp(value.value, 'ok'));
client = praxo.mcp_close(client);
assert(client.closed);

paged = praxo.mcp_list_tools(praxo.mcp_client(@transport_paged));
assert(numel(paged) == 2);
[name, found] = praxo.json_field(paged{2}, 'name');
assert(found && strcmp(name.value, 'two'));

must_fail(@() praxo.mcp_list_tools(praxo.mcp_client(@transport_duplicate)));
must_fail(@() praxo.mcp_list_tools(praxo.mcp_client(@transport_repeat_cursor)));
must_fail(@() praxo.mcp_call_tool(praxo.mcp_client(@transport_tool_error), ...
    'echo', praxo.json_make_object(cell(0, 2))));
disp('test_mcp passed');
end

function result = transport_ok(method, params) %#ok<INUSD>
switch method
    case 'initialize'
        result = initialize_result();
    case 'tools/list'
        result = tools_result({tool_node('echo')}, '');
    case 'tools/call'
        result = text_result('ok');
    otherwise
        result = praxo.json_make_object(cell(0, 2));
end
end

function result = transport_paged(method, params)
switch method
    case 'initialize'
        result = initialize_result();
    case 'tools/list'
        [cursor, found] = praxo.json_field(params, 'cursor');
        if found && strcmp(cursor.value, 'c1')
            result = tools_result({tool_node('two')}, '');
        else
            result = tools_result({tool_node('echo')}, 'c1');
        end
    case 'tools/call'
        result = text_result('ok');
    otherwise
        result = praxo.json_make_object(cell(0, 2));
end
end

function result = transport_duplicate(method, params) %#ok<INUSD>
switch method
    case 'initialize'
        result = initialize_result();
    case 'tools/list'
        result = tools_result({tool_node('echo'), tool_node('echo')}, '');
    otherwise
        result = praxo.json_make_object(cell(0, 2));
end
end

function result = transport_repeat_cursor(method, params) %#ok<INUSD>
switch method
    case 'initialize'
        result = initialize_result();
    case 'tools/list'
        result = tools_result({}, 'c1');
    otherwise
        result = praxo.json_make_object(cell(0, 2));
end
end

function result = transport_tool_error(method, params) %#ok<INUSD>
switch method
    case 'initialize'
        result = initialize_result();
    case 'tools/call'
        result = praxo.json_make_object({ ...
            'isError', praxo.json_make_bool(true)});
    otherwise
        result = praxo.json_make_object(cell(0, 2));
end
end

function result = initialize_result()
result = praxo.json_make_object({ ...
    'protocolVersion', praxo.json_make_string('2024-11-05'); ...
    'serverInfo', praxo.json_make_object({ ...
        'name', praxo.json_make_string('fake')})});
end

function result = tools_result(items, next_cursor)
pairs = {'tools', praxo.json_make_array(items)};
if ~isempty(next_cursor)
    pairs(end + 1, :) = {'nextCursor', praxo.json_make_string(next_cursor)};
end
result = praxo.json_make_object(pairs);
end

function node = tool_node(name)
node = praxo.json_make_object({ ...
    'name', praxo.json_make_string(name); ...
    'description', praxo.json_make_string('Tool'); ...
    'inputSchema', praxo.json_make_object({ ...
        'type', praxo.json_make_string('object')})});
end

function result = text_result(text)
result = praxo.json_make_object({ ...
    'content', praxo.json_make_array({ ...
        praxo.json_make_object({ ...
            'type', praxo.json_make_string('text'); ...
            'text', praxo.json_make_string(text)})})});
end

function must_fail(f)
try
    f();
    error('test:failure', 'Expected MCP failure');
catch err
    assert(strcmp(err.identifier, 'praxo:mcp'));
end
end
