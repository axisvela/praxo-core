function test_openai()
captured_path = '';
captured_payload = [];
calls = 0;
response_body = '';
status_code = 200;

    function result = transport(path, payload)
        captured_path = path;
        captured_payload = payload;
        calls = calls + 1;
        if status_code >= 200 && status_code < 300
            body = praxo.parse_json(response_body);
        else
            body = response_body;
        end
        result = struct('status', status_code, 'body', body);
    end

response_body = ['{"choices":[{"message":{"content":"hello","tool_calls":[' ...
    '{"id":"c1","type":"function","function":{"name":"echo",' ...
    '"arguments":"{\"text\":\"hi\"}"}}]},"finish_reason":"tool_calls"}],' ...
    '"usage":{"prompt_tokens":3,"completion_tokens":2}}'];
request = struct('messages', {{struct('role', 'user', 'content', 'hi')}}, ...
    'tools', {{struct('name', 'echo', 'description', 'Echo')}}, 'toolChoice', 'auto');
options = struct('baseUrl', 'http://example.test/v1', 'model', 'test-model', ...
    'transport', @transport);
response = praxo.openai_compatible(request, options);
assert(strcmp(captured_path, '/chat/completions'));
assert(calls == 1);
[value, found] = praxo.json_field(captured_payload, 'model');
assert(found && strcmp(value.kind, 'string') && strcmp(value.value, 'test-model'));
[value, found] = praxo.json_field(captured_payload, 'tool_choice');
assert(found && strcmp(value.value, 'auto'));
[messages, found] = praxo.json_field(captured_payload, 'messages');
assert(found && strcmp(messages.kind, 'array') && numel(messages.value) == 1);
[value, found] = praxo.json_field(messages.value{1}, 'content');
assert(found && strcmp(value.value, 'hi'));
[tools, found] = praxo.json_field(captured_payload, 'tools');
assert(found && strcmp(tools.kind, 'array') && numel(tools.value) == 1);
[function_node, found] = praxo.json_field(tools.value{1}, 'function');
assert(found && strcmp(function_node.kind, 'object'));
[value, found] = praxo.json_field(function_node, 'name');
assert(found && strcmp(value.value, 'echo'));
assert(strcmp(response.content, 'hello'));
assert(numel(response.toolCalls) == 1);
assert(strcmp(response.toolCalls{1}.id, 'c1'));
assert(strcmp(response.toolCalls{1}.name, 'echo'));
[value, found] = praxo.json_field(response.toolCalls{1}.arguments, 'text');
assert(found && strcmp(value.value, 'hi'));
assert(response.inputTokens == 3);
assert(response.outputTokens == 2);
assert(strcmp(response.finishReason, 'tool_calls'));

captured_payload = [];
calls = 0;
response_body = '{"choices":[{"message":{"content":"ok"}}]}';
assistant = struct('role', 'assistant', 'content', '', 'toolCalls', ...
    {{struct('id', 'c1', 'name', 'echo', 'arguments', praxo.parse_json('{"text":"bye"}'))}});
tool = struct('role', 'tool', 'content', '{"ok":true}', 'toolId', 'c1');
request = struct('messages', {{assistant, tool}}, 'tools', {{}});
options = struct('baseUrl', 'http://example.test/v1', 'model', 'test-model', ...
    'transport', @transport);
response = praxo.openai_compatible(request, options);
[messages, found] = praxo.json_field(captured_payload, 'messages');
assert(found && numel(messages.value) == 2);
[calls_node, found] = praxo.json_field(messages.value{1}, 'tool_calls');
assert(found && numel(calls_node.value) == 1);
[value, found] = praxo.json_field(calls_node.value{1}, 'id');
assert(found && strcmp(value.value, 'c1'));
[function_node, found] = praxo.json_field(calls_node.value{1}, 'function');
[value, found] = praxo.json_field(function_node, 'arguments');
parsed = praxo.parse_json(value.value);
[text, found] = praxo.json_field(parsed, 'text');
assert(found && strcmp(text.value, 'bye'));
[value, found] = praxo.json_field(messages.value{2}, 'tool_call_id');
assert(found && strcmp(value.value, 'c1'));

status_code = 500;
response_body = 'boom';
try
    praxo.openai_compatible(request, options);
    error('test:failure', 'Expected provider HTTP error');
catch err
    assert(strcmp(err.identifier, 'praxo:provider'));
    assert(strncmp(err.message, 'PROVIDER_HTTP', 13));
end

calls = 0;
options.baseUrl = '';
try
    praxo.openai_compatible(request, options);
    error('test:failure', 'Expected base URL error');
catch err
    assert(strcmp(err.identifier, 'praxo:provider'));
    assert(strncmp(err.message, 'PROVIDER_HTTP', 13));
end
assert(calls == 0);

status_code = 200;
response_body = ['{"choices":[{"message":{"content":"","tool_calls":[' ...
    '{"id":"c1","function":{"name":"echo","arguments":"not json"}}]}}]}'];
options.baseUrl = 'http://example.test/v1';
try
    praxo.openai_compatible(request, options);
    error('test:failure', 'Expected tool argument error');
catch err
    assert(strcmp(err.identifier, 'praxo:provider'));
    assert(strncmp(err.message, 'PROVIDER_JSON', 13));
end
disp('test_openai passed');
end
