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
stream_transport = option(options, 'stream_transport', []);
on_delta = option(request, 'onDelta', []);
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
if ~isempty(on_delta)
    payload = request_payload(model, max_tokens, messages, tools, tool_choice, true);
    if ~isempty(stream_transport)
        text = stream_transport('/v1/messages', payload);
    elseif ~isempty(transport)
        result = transport('/v1/messages', payload);
        if isstruct(result) && isscalar(result) && isfield(result, 'status') && isfield(result, 'body')
            if result.status < 200 || result.status >= 300
                provider_error('PROVIDER_HTTP', sprintf('provider returned HTTP %d', result.status));
            end
            text = result.body;
        else
            text = result;
        end
    else
        text = default_stream_transport(base_url, api_key, version, timeout, '/v1/messages', payload);
    end
    if ~ischar(text)
        provider_error('PROVIDER_HTTP', 'stream transport must return text');
    end
    response = parse_sse_response(text, on_delta);
    return;
end
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

function node = request_payload(model, max_tokens, messages, tools, tool_choice, stream)
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
if nargin >= 6 && stream
    pairs(end + 1, :) = {'stream', praxo.json_make_bool(true)};
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

function response = parse_sse_response(text, on_delta)
content = '';
input_tokens = 0;
output_tokens = 0;
cached_tokens = 0;
finish_reason = '';
done = false;
call_indexes = [];
call_ids = {};
call_names = {};
call_arguments = {};
lines = regexp(text, '\r?\n', 'split');
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line) || numel(line) < 5 || ~strcmp(line(1:5), 'data:')
        continue;
    end
    chunk = strtrim(line(6:end));
    if isempty(chunk)
        continue;
    end
    try
        event = praxo.parse_json(chunk);
    catch
        provider_error('MODEL_STREAM', 'invalid SSE packet');
    end
    [type_node, has_type] = praxo.json_field(event, 'type');
    kind = '';
    if has_type && strcmp(type_node.kind, 'string')
        kind = type_node.value;
    end
    if strcmp(kind, 'message_start')
        [message_node, has_message] = praxo.json_field(event, 'message');
        if has_message && strcmp(message_node.kind, 'object')
            [usage, has_usage] = praxo.json_field(message_node, 'usage');
            if has_usage && strcmp(usage.kind, 'object')
                [node, found] = praxo.json_field(usage, 'input_tokens');
                if found && strcmp(node.kind, 'number')
                    input_tokens = node.value;
                end
                [node, found] = praxo.json_field(usage, 'cache_read_input_tokens');
                if found && strcmp(node.kind, 'number')
                    cached_tokens = node.value;
                end
            end
        end
    elseif strcmp(kind, 'content_block_start')
        index = numel(call_indexes);
        [index_node, has_index] = praxo.json_field(event, 'index');
        if has_index && strcmp(index_node.kind, 'number')
            index = index_node.value;
        end
        [block, has_block] = praxo.json_field(event, 'content_block');
        if has_block && strcmp(block.kind, 'object')
            [block_type, has_block_type] = praxo.json_field(block, 'type');
            if has_block_type && strcmp(block_type.kind, 'string') && strcmp(block_type.value, 'tool_use')
                call_indexes(end + 1) = index;
                [id_node, has_id] = praxo.json_field(block, 'id');
                call_ids{end + 1} = ternary(has_id && strcmp(id_node.kind, 'string'), id_node.value, '');
                [name_node, has_name] = praxo.json_field(block, 'name');
                call_names{end + 1} = ternary(has_name && strcmp(name_node.kind, 'string'), name_node.value, '');
                call_arguments{end + 1} = '';
            end
        end
    elseif strcmp(kind, 'content_block_delta')
        index = 0;
        [index_node, has_index] = praxo.json_field(event, 'index');
        if has_index && strcmp(index_node.kind, 'number')
            index = index_node.value;
        end
        [delta, has_delta] = praxo.json_field(event, 'delta');
        if has_delta && strcmp(delta.kind, 'object')
            [delta_type, has_delta_type] = praxo.json_field(delta, 'type');
            if has_delta_type && strcmp(delta_type.kind, 'string')
                if strcmp(delta_type.value, 'text_delta')
                    [piece_node, has_piece] = praxo.json_field(delta, 'text');
                    if has_piece && strcmp(piece_node.kind, 'string') && ~isempty(piece_node.value)
                        content = [content piece_node.value];
                        on_delta(piece_node.value);
                    end
                elseif strcmp(delta_type.value, 'input_json_delta')
                    [partial_node, has_partial] = praxo.json_field(delta, 'partial_json');
                    if has_partial && strcmp(partial_node.kind, 'string')
                        slot = find(call_indexes == index, 1);
                        if ~isempty(slot)
                            call_arguments{slot} = [call_arguments{slot} partial_node.value];
                        end
                    end
                end
            end
        end
    elseif strcmp(kind, 'message_delta')
        [delta, has_delta] = praxo.json_field(event, 'delta');
        if has_delta && strcmp(delta.kind, 'object')
            [reason_node, has_reason] = praxo.json_field(delta, 'stop_reason');
            if has_reason && strcmp(reason_node.kind, 'string') && ~isempty(reason_node.value)
                finish_reason = reason_node.value;
            end
        end
        [usage, has_usage] = praxo.json_field(event, 'usage');
        if has_usage && strcmp(usage.kind, 'object')
            [node, found] = praxo.json_field(usage, 'output_tokens');
            if found && strcmp(node.kind, 'number')
                output_tokens = node.value;
            end
        end
    elseif strcmp(kind, 'message_stop')
        done = true;
    elseif strcmp(kind, 'error')
        provider_error('MODEL_STREAM', 'anthropic: provider stream error');
    end
end
if ~done && isempty(finish_reason)
    provider_error('MODEL_STREAM', 'stream ended before completion');
end
[~, order] = sort(call_indexes);
calls = {};
for k = 1:numel(order)
    slot = order(k);
    if isempty(call_names{slot})
        continue;
    end
    if isempty(call_arguments{slot})
        arguments = praxo.json_make_object({});
    else
        try
            arguments = praxo.parse_json(call_arguments{slot});
        catch
            provider_error('PROVIDER_JSON', 'anthropic: invalid tool arguments');
        end
        if ~strcmp(arguments.kind, 'object')
            provider_error('PROVIDER_JSON', 'anthropic: tool arguments must be an object');
        end
    end
    calls{end + 1} = struct('id', call_ids{slot}, 'name', call_names{slot}, ...
        'arguments', arguments);
end
response = struct('content', content, 'toolCalls', {calls}, ...
    'inputTokens', input_tokens, 'outputTokens', output_tokens, ...
    'finishReason', finish_reason);
end

function text = default_stream_transport(base_url, api_key, version, timeout, path, payload)
raw = praxo.encode_json(payload);
web_options = weboptions('MediaType', 'application/json', ...
    'ContentType', 'text', 'Timeout', timeout, ...
    'HeaderFields', {'x-api-key', api_key; 'anthropic-version', version});
try
    text = webwrite([base_url path], raw, web_options);
catch err
    provider_error('PROVIDER_HTTP', err.message);
end
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
