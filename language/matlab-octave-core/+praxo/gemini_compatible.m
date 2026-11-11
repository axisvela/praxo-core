function response = gemini_compatible(request, options)
if ~isstruct(request) || ~isscalar(request)
    provider_error('PROVIDER_HTTP', 'request must be a struct');
end
if ~isstruct(options) || ~isscalar(options)
    provider_error('PROVIDER_HTTP', 'options must be a struct');
end
base_url = option(options, 'baseUrl', '');
model = option(options, 'model', '');
api_key = option(options, 'apiKey', '');
max_output_tokens = option(options, 'maxOutputTokens', 0);
timeout = option(options, 'timeout', 120);
transport = option(options, 'transport', []);
if isempty(base_url)
    provider_error('PROVIDER_HTTP', 'provider base URL is required');
end
if isempty(api_key)
    provider_error('MODEL_CONFIG', 'gemini: API key is required');
end
if isempty(model)
    provider_error('MODEL_CONFIG', 'gemini: model is required');
end
base_url = regexprep(base_url, '/+$', '');
messages = option(request, 'messages', {});
tools = option(request, 'tools', {});
tool_choice = option(request, 'toolChoice', '');
payload = request_payload(messages, tools, tool_choice, max_output_tokens);
path = ['/v1beta/models/' model ':generateContent'];
if isempty(transport)
    result = default_transport(base_url, api_key, timeout, path, payload);
else
    result = transport(path, payload);
end
if ~isstruct(result) || ~isscalar(result) || ~isfield(result, 'status') || ~isfield(result, 'body')
    provider_error('PROVIDER_HTTP', 'provider transport returned an invalid result');
end
if result.status < 200 || result.status >= 300
    provider_error('PROVIDER_HTTP', sprintf('provider returned HTTP %d', result.status));
end
response = parse_response(result.body);
end

function node = request_payload(messages, tools, tool_choice, max_output_tokens)
system = {};
contents = {};
pending = {};
names = containers.Map('KeyType', 'char', 'ValueType', 'char');
for i = 1:numel(messages)
    message = messages{i};
    role = option(message, 'role', '');
    if strcmp(role, 'system')
        content = option(message, 'content', '');
        if ~isempty(content)
            system{end + 1} = praxo.json_make_object({ ...
                'text', praxo.json_make_string(content)});
        end
    elseif strcmp(role, 'tool')
        id = option(message, 'toolId', '');
        if isKey(names, id)
            name = names(id);
        elseif ~isempty(id)
            name = id;
        else
            name = 'tool';
        end
        pending{end + 1} = praxo.json_make_object({ ...
            'functionResponse', praxo.json_make_object({ ...
                'name', praxo.json_make_string(name); ...
                'response', praxo.json_make_object({ ...
                    'result', praxo.json_make_string(option(message, 'content', ''))})})});
    else
        if ~isempty(pending)
            contents{end + 1} = praxo.json_make_object({ ...
                'role', praxo.json_make_string('user'); ...
                'parts', praxo.json_make_array(pending)});
            pending = {};
        end
        parts = message_parts(message);
        if ~isempty(parts)
            if strcmp(role, 'assistant')
                gemini_role = 'model';
            else
                gemini_role = 'user';
            end
            contents{end + 1} = praxo.json_make_object({ ...
                'role', praxo.json_make_string(gemini_role); ...
                'parts', praxo.json_make_array(parts)});
        end
        calls = option(message, 'toolCalls', {});
        for j = 1:numel(calls)
            names(calls{j}.id) = calls{j}.name;
        end
    end
end
if ~isempty(pending)
    contents{end + 1} = praxo.json_make_object({ ...
        'role', praxo.json_make_string('user'); ...
        'parts', praxo.json_make_array(pending)});
end
pairs = {'contents', praxo.json_make_array(contents)};
if ~isempty(system)
    pairs(end + 1, :) = {'system_instruction', praxo.json_make_object({ ...
        'parts', praxo.json_make_array(system)})};
end
if ~isempty(tools)
    declarations = cell(1, numel(tools));
    for i = 1:numel(tools)
        tool = tools{i};
        declarations{i} = praxo.json_make_object({ ...
            'name', praxo.json_make_string(tool.name); ...
            'description', praxo.json_make_string(option(tool, 'description', '')); ...
            'parameters', praxo.json_make_object({ ...
                'type', praxo.json_make_string('object')})});
    end
    tool_groups = {praxo.json_make_object({ ...
        'functionDeclarations', praxo.json_make_array(declarations)})};
    pairs(end + 1, :) = {'tools', praxo.json_make_array(tool_groups)};
    if strcmp(tool_choice, 'required')
        mode = 'ANY';
    elseif strcmp(tool_choice, 'none')
        mode = 'NONE';
    else
        mode = 'AUTO';
    end
    pairs(end + 1, :) = {'toolConfig', praxo.json_make_object({ ...
        'functionCallingConfig', praxo.json_make_object({ ...
            'mode', praxo.json_make_string(mode)})})};
end
if max_output_tokens > 0
    pairs(end + 1, :) = {'generationConfig', praxo.json_make_object({ ...
        'maxOutputTokens', praxo.json_make_number(max_output_tokens)})};
end
node = praxo.json_make_object(pairs);
end

function parts = message_parts(message)
parts = {};
content = option(message, 'content', '');
if ~isempty(content)
    parts{end + 1} = praxo.json_make_object({ ...
        'text', praxo.json_make_string(content)});
end
calls = option(message, 'toolCalls', {});
for i = 1:numel(calls)
    call = calls{i};
    parts{end + 1} = praxo.json_make_object({ ...
        'functionCall', praxo.json_make_object({ ...
            'name', praxo.json_make_string(call.name); ...
            'args', call.arguments})});
end
end

function response = parse_response(data)
if ~isstruct(data) || ~strcmp(data.kind, 'object')
    provider_error('PROVIDER_JSON', 'provider returned invalid JSON');
end
[error_node, has_error] = praxo.json_field(data, 'error');
if has_error && strcmp(error_node.kind, 'object')
    provider_error('PROVIDER_HTTP', 'gemini: provider error');
end
[candidates, has_candidates] = praxo.json_field(data, 'candidates');
if ~has_candidates || ~strcmp(candidates.kind, 'array') || isempty(candidates.value)
    provider_error('PROVIDER_HTTP', 'gemini: empty response');
end
candidate = candidates.value{1};
[content, has_content] = praxo.json_field(candidate, 'content');
parts = {};
if has_content && strcmp(content.kind, 'object')
    [parts_node, has_parts] = praxo.json_field(content, 'parts');
    if has_parts && strcmp(parts_node.kind, 'array')
        parts = parts_node.value;
    end
end
text = '';
calls = {};
for i = 1:numel(parts)
    part = parts{i};
    [text_node, has_text] = praxo.json_field(part, 'text');
    if has_text && strcmp(text_node.kind, 'string')
        text = [text text_node.value];
    end
    [call_node, has_call] = praxo.json_field(part, 'functionCall');
    if has_call && strcmp(call_node.kind, 'object')
        [name_node, has_name] = praxo.json_field(call_node, 'name');
        [args_node, has_args] = praxo.json_field(call_node, 'args');
        arguments = praxo.json_make_object({});
        if has_args && strcmp(args_node.kind, 'object')
            arguments = args_node;
        end
        calls{end + 1} = struct( ...
            'id', sprintf('call-%d', numel(calls) + 1), ...
            'name', ternary(has_name && strcmp(name_node.kind, 'string'), name_node.value, ''), ...
            'arguments', arguments);
    end
end
[usage, has_usage] = praxo.json_field(data, 'usageMetadata');
input_tokens = 0;
output_tokens = 0;
if has_usage && strcmp(usage.kind, 'object')
    [input_node, has_input] = praxo.json_field(usage, 'promptTokenCount');
    if has_input && strcmp(input_node.kind, 'number')
        input_tokens = input_node.value;
    end
    [output_node, has_output] = praxo.json_field(usage, 'candidatesTokenCount');
    if has_output && strcmp(output_node.kind, 'number')
        output_tokens = output_node.value;
    end
end
[finish_node, has_finish] = praxo.json_field(candidate, 'finishReason');
finish_reason = '';
if has_finish && strcmp(finish_node.kind, 'string')
    finish_reason = finish_node.value;
end
response = struct('content', text, 'toolCalls', {calls}, ...
    'inputTokens', input_tokens, 'outputTokens', output_tokens, ...
    'finishReason', finish_reason);
end

function result = default_transport(base_url, api_key, timeout, path, payload)
raw = praxo.encode_json(payload);
web_options = weboptions('MediaType', 'application/json', ...
    'ContentType', 'json', 'Timeout', timeout, ...
    'HeaderFields', {'x-goog-api-key', api_key});
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
