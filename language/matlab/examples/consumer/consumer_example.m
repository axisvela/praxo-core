function consumer_example()
    [result, effects] = run_case('public');
    assert(isempty(result.errorCode));
    assert(strcmp(result.output, 'recorded'));
    assert(effects == 1);
    fprintf('allow: recorded; effects=%d\n', effects);

    [result, effects] = run_case('private');
    assert(~isempty(result.errorCode));
    assert(~isempty(strfind(result.errorMessage, 'AGENT_POLICY_DENIED')));
    assert(effects == 0);
    fprintf('deny: policy rejected; effects=%d\n', effects);
end

function [result, effects] = run_case(target)
    state = containers.Map('KeyType', 'char', 'ValueType', 'double');
    state('calls') = 0;
    state('effects') = 0;
    model = @(request) fixture_model(request, target, state);
    tool = struct('name', 'record', ...
        'description', 'Record a target in an in-memory counter.', ...
        'invoke', @(arguments) record_invoke(arguments, state));
    options = praxo.agent_options(model);
    options.tools = {tool};
    options.allowedTools = {'record'};
    options.toolSelection = {'record'};
    options.maxSteps = 3;
    options.policy = @authorize;
    options.requirePolicy = true;
    options.requireToolScope = true;
    result = praxo.agent_run('Record the requested target.', model, options.tools, options);
    effects = state('effects');
end

function response = fixture_model(request, target, state)
    calls = state('calls') + 1;
    state('calls') = calls;
    if calls > 1
        response = struct('content', 'recorded');
        return;
    end
    arguments = praxo.json_make_object({ ...
        'target', praxo.json_make_string(target)});
    call = struct('id', 'record-1', 'name', 'record', 'arguments', arguments);
    response = struct('content', '', 'toolCalls', {{call}});
end

function value = record_invoke(arguments, state)
    action = struct('kind', 'tool.invoke', 'toolName', 'record', 'arguments', arguments);
    if ~authorize(action)
        error('praxo:AGENT_POLICY_DENIED', ...
            'AGENT_POLICY_DENIED: only the public target is permitted');
    end
    state('effects') = state('effects') + 1;
    value = praxo.parse_json('"recorded"');
end

function allowed = authorize(action)
    allowed = false;
    if strcmp(action.kind, 'model.generate')
        allowed = true;
    elseif strcmp(action.kind, 'tool.invoke')
        [target, found] = praxo.json_field(action.arguments, 'target');
        allowed = strcmp(action.toolName, 'record') && found && ...
            strcmp(target.kind, 'string') && strcmp(target.value, 'public');
    end
end
