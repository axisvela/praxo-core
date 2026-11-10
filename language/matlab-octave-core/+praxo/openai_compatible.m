function response = openai_compatible(request, options)
if ~isstruct(request) || ~isscalar(request)
    provider_error('PROVIDER_HTTP', 'request must be a struct');
end
if ~isstruct(options) || ~isscalar(options)
    provider_error('PROVIDER_HTTP', 'options must be a struct');
end
base_url = option(options, 'baseUrl', '');
if isempty(base_url)
    provider_error('PROVIDER_HTTP', 'provider base URL is required');
end
base_url = regexprep(base_url, '/+$', '');
model = option(options, 'model', '');
api_key = option(options, 'apiKey', '');
timeout = option(options, 'timeout', 120);
transport = option(options, 'transport', []);
messages = option(request, 'messages', {});
tools = option(request, 'tools', {});
tool_choice = option(request, 'toolChoice', '');
if isempty(tool_choice)
    tool_choice = option(options, 'toolChoice', '');
end
payload = request_payload(model, messages, tools, tool_choice);
if isempty(transport)
    result = default_transport(base_url, api_key, timeout, '/chat/completions', payload);
else
    result = transport('/chat/completions', payload);
end
if ~isstruct(result) || ~isscalar(result) || ~isfield(result, 'status') || ~isfield(result, 'body')
    provider_error('PROVIDER_HTTP', 'provider transport returned an invalid result');
end
if result.status < 200 || result.status >= 300
    text = '';
    try
        text = praxo.encode_json(result.body);
    catch
    end
    if numel(text) > 4096
        text = text(1:4096);
    end
    provider_error('PROVIDER_HTTP', sprintf('provider returned HTTP %d: %s', result.status, text));
end
response = parse_response(result.body);
end

function node = request_payload(model, messages, tools, tool_choice)
pairs = {'model', praxo.json_make_string(model)};
encoded_messages = cell(1, numel(messages));
for i = 1:numel(messages)
    encoded_messages{i} = message_payload(messages{i});
end
pairs(end + 1, :) = {'messages', praxo.json_make_array(encoded_messages)};
if ~isempty(tools)
    encoded_tools = cell(1, numel(tools));
    for i = 1:numel(tools)
        item = tools{i};
        description = '';
        if isfield(item, 'description')
            description = item.description;
        end
        parameters = praxo.json_make_object({'type', praxo.json_make_string('object')});
        if isfield(item, 'parameters') && isstruct(item.parameters) && isfield(item.parameters, 'kind')
            parameters = item.parameters;
        end
        function_pairs = { ...
            'name', praxo.json_make_string(item.name); ...
            'description', praxo.json_make_string(description); ...
            'parameters', parameters};
        encoded_tools{i} = praxo.json_make_object({ ...
            'type', praxo.json_make_string('function'); ...
            'function', praxo.json_make_object(function_pairs)});
    end
    pairs(end + 1, :) = {'tools', praxo.json_make_array(encoded_tools)};
end
if ~isempty(tool_choice)
    pairs(end + 1, :) = {'tool_choice', praxo.json_make_string(tool_choice)};
end
node = praxo.json_make_object(pairs);
end

function node = message_payload(message)
role = '';
content = '';
blocks = {};
calls = {};
tool_id = '';
if isfield(message, 'role')
    role = message.role;
end
if isfield(message, 'content')
    content = message.content;
end
if isfield(message, 'contentBlocks')
    blocks = message.contentBlocks;
end
if isfield(message, 'toolCalls')
    calls = message.toolCalls;
end
if isfield(message, 'toolId')
    tool_id = message.toolId;
end
if isempty(content) && ~isempty(blocks)
    parts = {};
    for i = 1:numel(blocks)
        block = blocks{i};
        if isstruct(block) && isfield(block, 'type') && strcmp(block.type, 'text') && ...
                isfield(block, 'text') && ischar(block.text)
            parts{end + 1} = block.text;
        end
    end
    content = strjoin(parts, '');
end
pairs = {'role', praxo.json_make_string(role); ...
    'content', praxo.json_make_string(content)};
if strcmp(role, 'assistant') && ~isempty(calls)
    encoded_calls = cell(1, numel(calls));
    for i = 1:numel(calls)
        call = calls{i};
        arguments = praxo.json_make_object({});
        if isfield(call, 'arguments')
            arguments = call.arguments;
        end
        function_pairs = { ...
            'name', praxo.json_make_string(call.name); ...
            'arguments', praxo.json_make_string(praxo.encode_json(arguments))};
        encoded_calls{i} = praxo.json_make_object({ ...
            'id', praxo.json_make_string(call.id); ...
            'type', praxo.json_make_string('function'); ...
            'function', praxo.json_make_object(function_pairs)});
    end
    pairs(end + 1, :) = {'tool_calls', praxo.json_make_array(encoded_calls)};
end
if strcmp(role, 'tool') && ~isempty(tool_id)
    pairs(end + 1, :) = {'tool_call_id', praxo.json_make_string(tool_id)};
end
node = praxo.json_make_object(pairs);
end

function response = parse_response(data)
if ~isstruct(data) || ~isscalar(data) || ~isfield(data, 'kind') || ~strcmp(data.kind, 'object')
    provider_error('PROVIDER_JSON', 'provider returned invalid JSON');
end
[provider_error_node, has_error] = praxo.json_field(data, 'error');
if has_error && strcmp(provider_error_node.kind, 'object')
    [message_node, has_message] = praxo.json_field(provider_error_node, 'message');
    text = '';
    if has_message && strcmp(message_node.kind, 'string')
        text = message_node.value;
    end
    provider_error('PROVIDER_HTTP', text);
end
[choices, has_choices] = praxo.json_field(data, 'choices');
if ~has_choices || ~strcmp(choices.kind, 'array') || isempty(choices.value)
    provider_error('PROVIDER_JSON', 'provider returned no choices');
end
choice = choices.value{1};
[message, has_message] = praxo.json_field(choice, 'message');
if ~has_message || ~strcmp(message.kind, 'object')
    provider_error('PROVIDER_JSON', 'provider returned an invalid message');
end
[content_node, has_content] = praxo.json_field(message, 'content');
content = '';
if has_content && strcmp(content_node.kind, 'string')
    content = content_node.value;
end
calls = {};
[calls_node, has_calls] = praxo.json_field(message, 'tool_calls');
if has_calls && strcmp(calls_node.kind, 'array')
    for i = 1:numel(calls_node.value)
        call = calls_node.value{i};
        [id_node, has_id] = praxo.json_field(call, 'id');
        identifier = '';
        if has_id && strcmp(id_node.kind, 'string')
            identifier = id_node.value;
        end
        [function_node, has_function] = praxo.json_field(call, 'function');
        name = '';
        arguments = praxo.json_make_object({});
        if has_function && strcmp(function_node.kind, 'object')
            [name_node, has_name] = praxo.json_field(function_node, 'name');
            if has_name && strcmp(name_node.kind, 'string')
                name = name_node.value;
            end
            [arguments_node, has_arguments] = praxo.json_field(function_node, 'arguments');
            if has_arguments && strcmp(arguments_node.kind, 'string') && ~isempty(arguments_node.value)
                try
                    arguments = praxo.parse_json(arguments_node.value);
                catch
                    provider_error('PROVIDER_JSON', 'invalid tool call arguments');
                end
            elseif has_arguments && strcmp(arguments_node.kind, 'object')
                arguments = arguments_node;
            end
            if ~strcmp(arguments.kind, 'object')
                provider_error('PROVIDER_JSON', 'tool call arguments must be an object');
            end
        end
        calls{end + 1} = struct('id', identifier, 'name', name, 'arguments', arguments);
    end
end
[usage, has_usage] = praxo.json_field(data, 'usage');
input_tokens = 0;
output_tokens = 0;
if has_usage && strcmp(usage.kind, 'object')
    [input_node, has_input] = praxo.json_field(usage, 'prompt_tokens');
    if has_input && strcmp(input_node.kind, 'number')
        input_tokens = input_node.value;
    end
    [output_node, has_output] = praxo.json_field(usage, 'completion_tokens');
    if has_output && strcmp(output_node.kind, 'number')
        output_tokens = output_node.value;
    end
end
[finish_node, has_finish] = praxo.json_field(choice, 'finish_reason');
finish_reason = '';
if has_finish && strcmp(finish_node.kind, 'string')
    finish_reason = finish_node.value;
end
response = struct('content', content, 'toolCalls', {calls}, ...
    'inputTokens', input_tokens, 'outputTokens', output_tokens, ...
    'finishReason', finish_reason);
end

function result = default_transport(base_url, api_key, timeout, path, payload)
raw = praxo.encode_json(payload);
if isempty(api_key)
    web_options = weboptions('MediaType', 'application/json', ...
        'ContentType', 'json', 'Timeout', timeout);
else
    web_options = weboptions('MediaType', 'application/json', ...
        'ContentType', 'json', 'Timeout', timeout, ...
        'HeaderFields', {'Authorization', ['Bearer ' api_key]});
end
try
    body = webwrite([base_url path], raw, web_options);
    result = struct('status', 200, 'body', praxo.parse_json(body));
catch err
    provider_error('PROVIDER_HTTP', err.message);
end
end

function value = option(record, name, fallback)
if isstruct(record) && isfield(record, name)
    value = record.(name);
else
    value = fallback;
end
end

function provider_error(code, message)
error('praxo:provider', '%s: %s', code, message);
end
