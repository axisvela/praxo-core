function signal_trends()
    signal = [0.20, 0.25, 0.30, 0.90, 0.35, 0.22, 1.20, 0.28, 0.24, 0.26];
    threshold = 0.80;

    [result, reads] = run_signal('fixture', false, signal, threshold);
    assert(isempty(result.errorCode));
    assert(reads == 1);
    fprintf('signal report: %s\n', result.output);

    [denied, deniedReads] = run_signal('other', false, signal, threshold);
    assert(strcmp(denied.errorCode, 'AGENT_POLICY_DENIED'));
    assert(deniedReads == 0);

    [failed, failedReads] = run_signal('fixture', true, signal, threshold);
    assert(strcmp(failed.errorCode, 'TOOL_ERROR'));
    assert(failedReads == 1);

    fprintf('Octave/MATLAB signal-trends tutorial: all checks passed\n');
end

function [result, reads] = run_signal(dataset, simulateFailure, signal, threshold)
    state = containers.Map('KeyType', 'char', 'ValueType', 'double');
    state('calls') = 0;
    state('toolCalls') = 0;
    model = @(request) fixture_model(request, dataset, state);
    tool = struct('name', 'review_signal', ...
        'description', 'Compute fixed signal metrics; no writes.', ...
        'invoke', @(arguments) review_invoke(arguments, state, simulateFailure, signal, threshold));
    options = praxo.agent_options(model);
    options.tools = {tool};
    options.allowedTools = {'review_signal'};
    options.toolSelection = {'review_signal'};
    options.maxSteps = 3;
    options.policy = @authorize;
    options.requirePolicy = true;
    options.requireToolScope = true;
    result = praxo.agent_run('Review the fixed signal and report computed metrics only.', ...
                             model, options.tools, options);
    reads = state('toolCalls');
end

function response = fixture_model(request, dataset, state)
    calls = state('calls') + 1;
    state('calls') = calls;
    toolMessages = {};
    for i = 1:numel(request.messages)
        if strcmp(request.messages{i}.role, 'tool')
            toolMessages{end + 1} = request.messages{i};
        end
    end
    if ~isempty(toolMessages)
        summary = praxo.parse_json(toolMessages{end}.content);
        report = praxo.json_make_object({ ...
            'signal', summary; ...
            'mutating_actions', praxo.parse_json('[]')});
        response = struct('content', praxo.encode_json(report));
        return;
    end
    arguments = praxo.json_make_object({ ...
        'name', praxo.json_make_string(dataset)});
    call = struct('id', 'signal-1', 'name', 'review_signal', 'arguments', arguments);
    response = struct('content', '', 'toolCalls', {{call}});
end

function value = review_invoke(arguments, state, simulateFailure, signal, threshold)
    state('toolCalls') = state('toolCalls') + 1;
    [name, found] = praxo.json_field(arguments, 'name');
    if ~found || ~strcmp(name.kind, 'string') || ~strcmp(name.value, 'fixture')
        error('praxo:AGENT_POLICY_DENIED', 'unknown signal fixture');
    end
    if simulateFailure
        error('praxo:TOOL_ERROR', 'simulated signal dependency unavailable');
    end
    anomalies = find(signal > threshold);
    firstAnomaly = 0;
    if ~isempty(anomalies), firstAnomaly = anomalies(1); end
    value = praxo.json_make_object({ ...
        'source', praxo.json_make_string('fixture'); ...
        'samples', praxo.json_make_number(numel(signal)); ...
        'mean', praxo.json_make_number(mean(signal)); ...
        'peak_to_peak', praxo.json_make_number(max(signal) - min(signal)); ...
        'rms', praxo.json_make_number(sqrt(mean(signal .^ 2))); ...
        'anomalies', praxo.json_make_number(numel(anomalies)); ...
        'first_anomaly', praxo.json_make_number(firstAnomaly)});
end

function allowed = authorize(action)
    allowed = false;
    if strcmp(action.kind, 'model.generate')
        allowed = true;
    elseif strcmp(action.kind, 'tool.invoke')
        [name, found] = praxo.json_field(action.arguments, 'name');
        allowed = strcmp(action.toolName, 'review_signal') && found && ...
            strcmp(name.kind, 'string') && strcmp(name.value, 'fixture');
    end
end
