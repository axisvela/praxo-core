function response = anthropic_compatible(request, options)
if ~isstruct(request) || ~isscalar(request)
    provider_error('PROVIDER_HTTP', 'request must be a struct');
end
if ~isstruct(options) || ~isscalar(options)
    provider_error('PROVIDER_HTTP', 'options must be a struct');
end
base_url = option(options, 'baseUrl', '');
model = option(options, 'model', '');
api_key = option(options, 'apiKey', '');
version = option(options, 'version', '2023-06-01');
max_tokens = option(options, 'maxTokens', 1024);
timeout = option(options, 'timeout', 120);
transport = option(options, 'transport', []);
if isempty(base_url)
    provider_error('PROVIDER_HTTP', 'provider base URL is required');
end
if isempty(api_key)
    provider_error('MODEL_CONFIG', 'anthropic: API key is required');
end
if isempty(model)
    provider_error('MODEL_CONFIG', 'anthropic: model is required');
end
base_url = regexprep(base_url, '/+$', '');
messages = option(request, 'messages', {});
tools = option(request, 'tools', {});
tool_choice = option(request, 'toolChoice', '');
payload = request_payload(model, max_tokens, messages, tools, tool_choice);
if isempty(transport)
    result = default_transport(base_url, api_key, version, timeout, '/v1/messages', payload);
else
    result = transport('/v1/messages', payload);
end
if ~isstruct(result) || ~isscalar(result) || ~isfield(result, 'status') || ~isfield(result, 'body')
    provider_error('PROVIDER_HTTP', 'provider transport returned an invalid result');
end
if result.status < 200 || result.status >= 300
    provider_error('PROVIDER_HTTP', sprintf('provider returned HTTP %d', result.status));
end
response = parse_response(result.body);
end

function node = request_payload(model, max_tokens, messages, tools, tool_choice)
system = '';
encoded_messages = {};
pending = {};
for i = 1:numel(messages)
    message = messages{i};
    role = option(message, 'role', '');
    if strcmp(role, 'system')
        content = option(message, 'content', '');
        if ~isempty(content)
            if ~isempty(system)
                system = [system sprintf('\n\n')];
            end
            system = [system content];
        end
    elseif strcmp(role, 'tool')
        pending{end + 1} = praxo.json_make_object({ ...
            'type', praxo.json_make_string('tool_result'); ...
            'tool_use_id', praxo.json_make_string(option(message, 'toolId', '')); ...
            'content', praxo.json_make_string(option(message, 'content', ''))});
    else
        if ~isempty(pending)
            encoded_messages{end + 1} = praxo.json_make_object({ ...
                'role', praxo.json_make_string('user'); ...
                'content', praxo.json_make_array(pending)});
            pending = {};
        end
        content = message_content(message);
        if ~isempty(content)
            encoded_messages{end + 1} = praxo.json_make_object({ ...
                'role', praxo.json_make_string(role); ...
                'content', praxo.json_make_array(content)});
        end
    end
end
if ~isempty(pending)
    encoded_messages{end + 1} = praxo.json_make_object({ ...
        'role', praxo.json_make_string('user'); ...
        'content', praxo.json_make_array(pending)});
end
pairs = {'model', praxo.json_make_string(model); ...
    'max_tokens', praxo.json_make_number(max_tokens); ...
    'messages', praxo.json_make_array(encoded_messages)};
if ~isempty(system)
    pairs(end + 1, :) = {'system', praxo.json_make_string(system)};
end
if ~isempty(tools)
    encoded_tools = cell(1, numel(tools));
    for i = 1:numel(tools)
        tool = tools{i};
        encoded_tools{i} = praxo.json_make_object({ ...
            'name', praxo.json_make_string(tool.name); ...
            'description', praxo.json_make_string(option(tool, 'description', '')); ...
            'input_schema', praxo.json_make_object({ ...
                'type', praxo.json_make_string('object')})});
    end
    pairs(end + 1, :) = {'tools', praxo.json_make_array(encoded_tools)};
    if strcmp(tool_choice, 'auto')
        pairs(end + 1, :) = {'tool_choice', praxo.json_make_object({ ...
            'type', praxo.json_make_string('auto')})};
    elseif strcmp(tool_choice, 'required')
        pairs(end + 1, :) = {'tool_choice', praxo.json_make_object({ ...
            'type', praxo.json_make_string('any')})};
    elseif strcmp(tool_choice, 'none')
        pairs(end + 1, :) = {'tool_choice', praxo.json_make_object({ ...
            'type', praxo.json_make_string('none')})};
    end
end
node = praxo.json_make_object(pairs);
end

function content = message_content(message)
content = {};
value = option(message, 'content', '');
if ~isempty(value)
    content{end + 1} = praxo.json_make_object({ ...
        'type', praxo.json_make_string('text'); ...
        'text', praxo.json_make_string(value)});
end
calls = option(message, 'toolCalls', {});
for i = 1:numel(calls)
    call = calls{i};
    content{end + 1} = praxo.json_make_object({ ...
        'type', praxo.json_make_string('tool_use'); ...
        'id', praxo.json_make_string(call.id); ...
        'name', praxo.json_make_string(call.name); ...
        'input', call.arguments});
end
end

function response = parse_response(data)
if ~isstruct(data) || ~strcmp(data.kind, 'object')
    provider_error('PROVIDER_JSON', 'provider returned invalid JSON');
end
[error_node, has_error] = praxo.json_field(data, 'error');
if has_error && strcmp(error_node.kind, 'object')
    provider_error('PROVIDER_HTTP', 'anthropic: provider error');
end
[content_node, has_content] = praxo.json_field(data, 'content');
if ~has_content || ~strcmp(content_node.kind, 'array')
    provider_error('PROVIDER_JSON', 'provider returned invalid content');
end
text = '';
calls = {};
for i = 1:numel(content_node.value)
    block = content_node.value{i};
    [type_node, has_type] = praxo.json_field(block, 'type');
    if ~has_type || ~strcmp(type_node.kind, 'string')
        continue;
    end
    if strcmp(type_node.value, 'text')
        [text_node, has_text] = praxo.json_field(block, 'text');
        if has_text && strcmp(text_node.kind, 'string')
            text = [text text_node.value];
        end
    elseif strcmp(type_node.value, 'tool_use')
        [id_node, has_id] = praxo.json_field(block, 'id');
        [name_node, has_name] = praxo.json_field(block, 'name');
        [input_node, has_input] = praxo.json_field(block, 'input');
        arguments = praxo.json_make_object({});
        if has_input && strcmp(input_node.kind, 'object')
            arguments = input_node;
        end
        calls{end + 1} = struct( ...
            'id', ternary(has_id && strcmp(id_node.kind, 'string'), id_node.value, ''), ...
            'name', ternary(has_name && strcmp(name_node.kind, 'string'), name_node.value, ''), ...
            'arguments', arguments);
    end
end
[usage, has_usage] = praxo.json_field(data, 'usage');
input_tokens = 0;
output_tokens = 0;
if has_usage && strcmp(usage.kind, 'object')
    [input_node, has_input] = praxo.json_field(usage, 'input_tokens');
    if has_input && strcmp(input_node.kind, 'number')
        input_tokens = input_node.value;
    end
    [output_node, has_output] = praxo.json_field(usage, 'output_tokens');
    if has_output && strcmp(output_node.kind, 'number')
        output_tokens = output_node.value;
    end
end
[finish_node, has_finish] = praxo.json_field(data, 'stop_reason');
finish_reason = '';
if has_finish && strcmp(finish_node.kind, 'string')
    finish_reason = finish_node.value;
end
response = struct('content', text, 'toolCalls', {calls}, ...
    'inputTokens', input_tokens, 'outputTokens', output_tokens, ...
    'finishReason', finish_reason);
end

function result = default_transport(base_url, api_key, version, timeout, path, payload)
raw = praxo.encode_json(payload);
web_options = weboptions('MediaType', 'application/json', ...
    'ContentType', 'json', 'Timeout', timeout, ...
    'HeaderFields', {'x-api-key', api_key; 'anthropic-version', version});
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

function value = ternary(condition, yes, no)
if condition
    value = yes;
else
    value = no;
end
end

function provider_error(code, message)
error('praxo:provider', '%s: %s', code, message);
end
