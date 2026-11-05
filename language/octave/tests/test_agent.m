function test_agent()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'agent-loop.json')));
vectors = field(document, 'vectors').value;
for i = 1:numel(vectors)
    input = field(vectors{i}, 'input');
    expect = field(vectors{i}, 'expect');
    raw_script = field(input, 'script').value;
    script = cell(1, numel(raw_script));
    for j = 1:numel(raw_script)
        raw = raw_script{j};
        response = struct('content', field(raw, 'content').value);
        response.outputTokens = node_value(raw, 'outputTokens', 0);
        raw_calls = node_value(raw, 'toolCalls', {});
        calls = cell(1, numel(raw_calls));
        for k = 1:numel(raw_calls)
            call = raw_calls{k};
            calls{k} = struct('id', field(call, 'id').value, 'name', field(call, 'name').value, ...
                'arguments', field(call, 'arguments'));
        end
        response.toolCalls = calls;
        script{j} = response;
    end
    options = struct('maxSteps', node_value(input, 'maxSteps', 8), 'maxTokens', node_value(input, 'maxTokens', 0));
    raw_tools = node_value(input, 'tools', {});
    tools = cell(1, numel(raw_tools));
    for j = 1:numel(raw_tools)
        tools{j} = struct('name', field(raw_tools{j}, 'name').value, 'invoke', @(args) args);
    end
    result = praxo.agent_run(field(input, 'prompt').value, scripted(script), tools, options);
    expected_events = field(expect, 'events').value;
    assert(numel(result.events) == numel(expected_events));
    for j = 1:numel(expected_events), assert(strcmp(result.events{j}, expected_events{j}.value)); end
    assert(result.toolInvocations == field(expect, 'toolInvocations').value);
    if has_field(expect, 'error')
        assert(strcmp(result.errorCode, field(expect, 'errorCode').value));
    else
        assert(isempty(result.errorCode));
        assert(strcmp(result.output, field(expect, 'output').value));
        assert(result.steps == field(expect, 'steps').value);
    end
end
args = praxo.parse_json('{"text":"hi"}');
call = struct('id', 'c1', 'name', 'echo', 'arguments', args);
response = struct('content', '', 'toolCalls', {{call}});
tool = struct('name', 'echo', 'invoke', @(value) value);
result = praxo.agent_run('x', scripted({response, struct('content', 'ok')}), {tool});
assert(strcmp(result.messages{3}.content, '{"text":"hi"}'));
assert(strcmp(result.messages{3}.toolCallId, 'c1'));
result = praxo.agent_run('x', scripted({response}), {});
assert(strcmp(result.errorCode, 'TOOL_NOT_FOUND') && isequal(result.events, {'run.started', 'run.failed'}));
result = praxo.agent_run('x', @broken, {});
assert(strcmp(result.errorCode, 'MODEL_ERROR') && isequal(result.events, {'run.started', 'run.failed'}));
result = praxo.agent_run('x', scripted({response}), {struct('name', 'echo', 'invoke', @broken)});
assert(strcmp(result.errorCode, 'TOOL_ERROR') && result.toolInvocations == 1);
assert(isequal(result.events, {'run.started', 'tool.call', 'run.failed'}));
result = praxo.agent_run('x', scripted({response}), {tool});
assert(strcmp(result.errorCode, 'MODEL_ERROR') && numel(result.messages) == 3);
result = praxo.agent_run('x', scripted({struct('content', 'bad', 'outputTokens', 2)}), {}, struct('maxTokens', 1));
assert(strcmp(result.errorCode, 'AGENT_MAX_TOKENS') && numel(result.messages) == 1);
result = praxo.agent_run('x', scripted({struct('content', 'ok', 'inputTokens', 1, 'outputTokens', 1)}), {}, struct('maxTokens', 2));
assert(isempty(result.errorCode) && result.inputTokens == 1 && result.outputTokens == 1);
result = praxo.agent_run('x', scripted({struct('content', '', 'toolCalls', {{struct('name', 'echo')}})}), {tool});
assert(strcmp(result.errorCode, 'MODEL_ERROR'));
bad_call = struct('id', 'c', 'name', 'echo', 'arguments', struct('kind', 'object', 'value', 42));
result = praxo.agent_run('x', scripted({struct('content', '', 'toolCalls', {{bad_call}})}), {tool});
assert(strcmp(result.errorCode, 'MODEL_ERROR') && result.toolInvocations == 0);
try
    praxo.agent_run('x', @broken, {}, struct('maxSteps', -1));
    error('test:failure', 'Expected invalid configuration');
catch err
    assert(strcmp(err.identifier, 'praxo:agent'));
end
secret = struct('name', 'secret', 'invoke', @(args) error('test:secret', 'invoked'));
echo = praxo.tool('echo', 'Echo', @(args) args);
call = struct('id', 'c1', 'name', 'echo', 'arguments', praxo.parse_json('{}'));
options = praxo.agent_options(scripted({struct('content', '', 'toolCalls', {{call}}), struct('content', 'done')}));
options.tools = {echo, secret};
options.toolSelection = {'echo'};
result = praxo.agent_run('use', options.model, options.tools, options);
assert(isempty(result.errorCode) && strcmp(result.output, 'done') && result.toolInvocations == 1);

seen = containers.Map();
seen('calls') = 0;
pii_model = @(request) capture_pii(request, seen);
options = praxo.agent_options(pii_model);
options.pii = true;
options.tools = {praxo.tool('echo', 'Echo', @(args) args)};
result = praxo.agent_run('a@b.com', pii_model, options.tools, options);
assert(strcmp(result.output, 'a@b.com'));
messages_seen = seen('messages');
assert(strcmp(messages_seen{1}.content, '[REDACTED:email]'));
[email, found] = praxo.json_field(messages_seen{2}.toolCalls{1}.arguments, 'email');
assert(found && strcmp(email.value, '[REDACTED:email]'));

schema = praxo.parse_json('{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}');
options = praxo.agent_options(scripted({struct('content', 'bad')}));
options.structuredOutput = praxo.structured_output(schema, 1, @(text) '{"name":"fixed"}');
result = praxo.agent_run('x', options.model, {}, options);
assert(isempty(result.errorCode) && strcmp(result.output, '{"name":"fixed"}'));

limited_calls = {struct('id', '1', 'name', 'echo', 'arguments', praxo.parse_json('{}')), ...
    struct('id', '2', 'name', 'echo', 'arguments', praxo.parse_json('{}'))};
options = praxo.agent_options(scripted({struct('content', '', 'toolCalls', {limited_calls})}));
options.tools = {praxo.tool('echo', 'Echo', @(args) args)};
options.callLimit = praxo.call_limit(0, 1);
result = praxo.agent_run('x', options.model, options.tools, options);
assert(strcmp(result.errorCode, 'AGENT_TOOL_CALL_LIMIT'));

disp('test_agent passed');
end

function response = capture_pii(request, seen)
seen('messages') = request.messages;
calls = seen('calls') + 1;
seen('calls') = calls;
if calls == 1
    call = struct('id', 'c1', 'name', 'echo', ...
        'arguments', praxo.parse_json('{"email":"a@b.com"}'));
    response = struct('content', 'a@b.com', 'toolCalls', {{call}});
else
    response = struct('content', 'a@b.com');
end
end

function model = scripted(steps)
index = 0;
model = @next;
    function response = next(request)
        assert(isfield(request, 'messages') && isfield(request, 'tools'));
        index = index + 1;
        if index > numel(steps), error('test:exhausted', 'Script exhausted'); end
        response = steps{index};
    end
end

function value = broken(~)
error('test:broken', 'Callback failed');
value = [];
end

function value = field(node, key)
index = find(strcmp(node.value(:, 1), key), 1, 'last');
assert(~isempty(index));
value = node.value{index, 2};
end

function value = node_value(node, key, fallback)
if has_field(node, key), value = field(node, key).value; else, value = fallback; end
end

function result = has_field(node, key)
result = any(strcmp(node.value(:, 1), key));
end
