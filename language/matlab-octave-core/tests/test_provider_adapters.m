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

disp('test_provider_adapters passed');
end
