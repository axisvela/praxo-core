function test_provider_adapters()
request = struct();
request.messages = { ...
    struct('role', 'system', 'content', 'be brief'), ...
    struct('role', 'user', 'content', 'hi')};
request.tools = {struct('name', 'echo', 'description', 'Echo')};
request.toolChoice = 'auto';

anthropic_body = praxo.parse_json(['{"content":[{"type":"text","text":"hello"},' ...
    '{"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],' ...
    '"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":4}}']);
anthropic_transport = @(path, payload) struct('status', 200, 'body', anthropic_body);
options = struct('baseUrl', 'https://example.test', 'model', 'claude-test', ...
    'apiKey', 'ak', 'transport', anthropic_transport);
response = praxo.anthropic_compatible(request, options);
assert(strcmp(response.content, 'hello'));
assert(strcmp(response.toolCalls{1}.id, 'tool-1'));
assert(strcmp(response.toolCalls{1}.name, 'echo'));
assert(response.inputTokens == 3);
assert(response.outputTokens == 4);
assert(strcmp(response.finishReason, 'end_turn'));

anthropic_deltas = {};
stream_events = { ...
    'data: {"type":"message_start","message":{"usage":{"input_tokens":4,"cache_read_input_tokens":1}}}', ...
    'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}', ...
    'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"he"}}', ...
    'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"llo"}}', ...
    'data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"call-1","name":"echo","input":{}}}', ...
    'data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"text\":"}}', ...
    'data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"hi\"}"}}', ...
    'data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":2}}', ...
    'data: {"type":"message_stop"}'};
stream_transport = @(path, payload) strjoin(stream_events, sprintf('\n\n'));
options = struct('baseUrl', 'https://example.test', 'model', 'claude-test', ...
    'apiKey', 'ak', 'stream_transport', stream_transport);
request.onDelta = @collect_anthropic_delta;
response = praxo.anthropic_compatible(request, options);
assert(isequal(anthropic_deltas, {'he', 'llo'}));
assert(strcmp(response.content, 'hello'));
assert(response.inputTokens == 4);
assert(response.outputTokens == 2);
assert(strcmp(response.finishReason, 'tool_use'));
assert(strcmp(response.toolCalls{1}.id, 'call-1'));
assert(strcmp(response.toolCalls{1}.name, 'echo'));
[text_node, has_text] = praxo.json_field(response.toolCalls{1}.arguments, 'text');
assert(has_text && strcmp(text_node.kind, 'string') && strcmp(text_node.value, 'hi'));

request.onDelta = [];
gemini_body = praxo.parse_json(['{"candidates":[{"content":{"parts":[' ...
    '{"text":"hello"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},' ...
    '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,' ...
    '"candidatesTokenCount":4}}']);
gemini_transport = @(path, payload) struct('status', 200, 'body', gemini_body);
options = struct('baseUrl', 'https://example.test', 'model', 'gemini-test', ...
    'apiKey', 'gk', 'transport', gemini_transport);
response = praxo.gemini_compatible(request, options);
assert(strcmp(response.content, 'hello'));
assert(strcmp(response.toolCalls{1}.name, 'echo'));
assert(response.inputTokens == 3);
assert(response.outputTokens == 4);
assert(strcmp(response.finishReason, 'STOP'));

gemini_deltas = {};
stream_events = { ...
    'data: {"candidates":[{"content":{"parts":[{"text":"he"}]}}]}', ...
    'data: {"candidates":[{"content":{"parts":[{"text":"llo"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":4,"candidatesTokenCount":2,"cachedContentTokenCount":1}}'};
stream_transport = @(path, payload) strjoin(stream_events, sprintf('\n\n'));
options = struct('baseUrl', 'https://example.test', 'model', 'gemini-test', ...
    'apiKey', 'gk', 'stream_transport', stream_transport);
request.onDelta = @collect_gemini_delta;
response = praxo.gemini_compatible(request, options);
assert(isequal(gemini_deltas, {'he', 'llo'}));
assert(strcmp(response.content, 'hello'));
assert(response.inputTokens == 4);
assert(response.outputTokens == 2);
assert(strcmp(response.finishReason, 'STOP'));
assert(strcmp(response.toolCalls{1}.name, 'echo'));
[text_node, has_text] = praxo.json_field(response.toolCalls{1}.arguments, 'text');
assert(has_text && strcmp(text_node.kind, 'string') && strcmp(text_node.value, 'hi'));

disp('test_provider_adapters passed');

    function collect_anthropic_delta(delta)
        anthropic_deltas{end + 1} = delta;
    end

    function collect_gemini_delta(delta)
        gemini_deltas{end + 1} = delta;
    end
end
