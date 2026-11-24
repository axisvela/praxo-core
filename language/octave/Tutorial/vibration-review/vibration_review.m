function vibration_review()
    args = argv();
    if any(strcmp(args, '--test'))
        run_tests();
        return;
    end
    anomaly = ~any(strcmp(args, '--normal'));
    failure = any(strcmp(args, '--simulate-failure'));
    [result, reads, drafts] = run_review('region-100', anomaly, failure);
    if ~isempty(result.errorCode)
        fprintf(stderr, 'vibration review failed: reads=%d drafts=%d; %s\n', reads, drafts, result.errorCode);
        exit(1);
    end
    fprintf('%s\n', result.output);
end

function run_tests()
    [result, reads, drafts] = run_review('region-100', true, false);
    assert(isempty(result.errorCode));
    assert(reads == 1 && drafts == 1);
    report = praxo.parse_json(result.output);
    [signal, signalFound] = praxo.json_field(report, 'signal');
    assert(signalFound);
    [flagNode, flagFound] = praxo.json_field(signal, 'flagged');
    [dominant, dominantFound] = praxo.json_field(signal, 'dominant_hz');
    [review, reviewFound] = praxo.json_field(report, 'review');
    [action, actionFound] = praxo.json_field(review, 'action');
    [commands, commandsFound] = praxo.json_field(report, 'equipment_commands');
    assert(flagFound && flagNode.value == true);
    assert(dominantFound && dominant.value >= 170 && dominant.value <= 190);
    assert(reviewFound && actionFound && strcmp(action.value, 'review_inspection'));
    assert(commandsFound && commands.value == 0);

    [normal, normalReads, normalDrafts] = run_review('region-100', false, false);
    assert(isempty(normal.errorCode) && normalReads == 1 && normalDrafts == 1);
    normalReport = praxo.parse_json(normal.output);
    [normalSignal, normalSignalFound] = praxo.json_field(normalReport, 'signal');
    [normalFlag, normalFlagFound] = praxo.json_field(normalSignal, 'flagged');
    [normalReview, normalReviewFound] = praxo.json_field(normalReport, 'review');
    [normalAction, normalActionFound] = praxo.json_field(normalReview, 'action');
    assert(normalSignalFound && normalFlagFound && normalFlag.value == false);
    assert(normalReviewFound && normalActionFound && strcmp(normalAction.value, 'review_normal'));

    [denied, deniedReads, deniedDrafts] = run_review('region-200', true, false);
    assert(strcmp(denied.errorCode, 'AGENT_POLICY_DENIED'));
    assert(deniedReads == 0 && deniedDrafts == 0);

    [failed, failedReads, failedDrafts] = run_review('region-100', true, true);
    assert(strcmp(failed.errorCode, 'TOOL_ERROR'));
    assert(failedReads == 1 && failedDrafts == 0);

    fprintf('Octave vibration-review tutorial: FFT branch, denial and failure passed\n');
end

function [result, reads, drafts] = run_review(region, anomaly, simulateFailure)
    state = containers.Map('KeyType', 'char', 'ValueType', 'double');
    state('reads') = 0;
    state('drafts') = 0;
    model = @(request) fixture_model(request, region, state);
    analyze = struct('name', 'analyze_vibration', ...
        'description', 'Compute FFT/RMS over fixed normal and anomalous samples; no device access.', ...
        'invoke', @(arguments) analyze_invoke(arguments, state, simulateFailure, anomaly));
    draft = struct('name', 'draft_review', ...
        'description', 'Draft a review-only inspection action; never commands equipment.', ...
        'invoke', @(arguments) draft_invoke(arguments, state));
    options = praxo.agent_options(model);
    options.tools = {analyze, draft};
    options.allowedTools = {'analyze_vibration', 'draft_review'};
    options.toolSelection = {'analyze_vibration', 'draft_review'};
    options.maxSteps = 4;
    options.policy = @(action) authorize(action, region);
    options.requirePolicy = true;
    options.requireToolScope = true;
    result = praxo.agent_run('Analyze fixed vibration samples and draft review-only findings.', ...
                             model, options.tools, options);
    reads = state('reads');
    drafts = state('drafts');
end

function response = fixture_model(request, region, state)
    tools = {};
    for i = 1:numel(request.messages)
        if strcmp(request.messages{i}.role, 'tool')
            tools{end + 1} = request.messages{i};
        end
    end
    if isempty(tools)
        arguments = praxo.json_make_object({'region', praxo.json_make_string(region)});
        call = struct('id', 'analysis-1', 'name', 'analyze_vibration', 'arguments', arguments);
        response = struct('content', '', 'toolCalls', {{call}});
        return;
    end
    evidence = praxo.parse_json(tools{1}.content);
    if numel(tools) == 1
        [flagNode, flagFound] = praxo.json_field(evidence, 'flagged');
        flagged = flagFound && flagNode.value;
        action = 'review_normal';
        if flagged, action = 'review_inspection'; end
        arguments = praxo.json_make_object({ ...
            'region', praxo.json_make_string(region); ...
            'action', praxo.json_make_string(action)});
        call = struct('id', 'review-1', 'name', 'draft_review', 'arguments', arguments);
        response = struct('content', '', 'toolCalls', {{call}});
        return;
    end
    review = praxo.parse_json(tools{end}.content);
    report = praxo.json_make_object({ ...
        'stage', praxo.json_make_string('vibration_reviewed'); ...
        'signal', evidence; ...
        'review', review; ...
        'equipment_commands', praxo.json_make_number(0)});
    response = struct('content', praxo.encode_json(report));
end

function value = analyze_invoke(arguments, state, simulateFailure, anomaly)
    state('reads') = state('reads') + 1;
    [region, found] = praxo.json_field(arguments, 'region');
    if ~found || ~strcmp(region.value, 'region-100')
        error('praxo:AGENT_POLICY_DENIED', 'region outside fixture');
    end
    if simulateFailure
        error('praxo:TOOL_ERROR', 'simulated vibration data unavailable');
    end
    fs = 1000;
    n = 256;
    t = (0:n-1) / fs;
    normal = sin(2*pi*50*t) + 0.05*sin(2*pi*200*t);
    sample = normal;
    if anomaly
        sample = sample + 1.5*sin(2*pi*180*t);
    end
    spectrum = abs(fft(sample)) / n;
    half = spectrum(1:n/2+1);
    half(2:end-1) = 2 * half(2:end-1);
    frequencies = (0:n/2) * fs / n;
    masked = half;
    masked(1) = 0;
    [~, index] = max(masked);
    dominant = frequencies(index);
    energy = sum(half .^ 2);
    highEnergy = sum(half(frequencies > 120) .^ 2);
    ratio = highEnergy / energy;
    value = praxo.json_make_object({ ...
        'region', praxo.json_make_string('region-100'); ...
        'samples', praxo.json_make_number(n); ...
        'dominant_hz', praxo.json_make_number(dominant); ...
        'rms', praxo.json_make_number(sqrt(mean(sample .^ 2))); ...
        'high_band_ratio', praxo.json_make_number(ratio); ...
        'flagged', praxo.json_make_bool(ratio > 0.10); ...
        'source', praxo.json_make_string('vibration_fixture')});
end

function value = draft_invoke(arguments, state)
    state('drafts') = state('drafts') + 1;
    [region, found] = praxo.json_field(arguments, 'region');
    [action, actionFound] = praxo.json_field(arguments, 'action');
    if ~found || ~strcmp(region.value, 'region-100') || ~actionFound || ...
       ~(strcmp(action.value, 'review_inspection') || strcmp(action.value, 'review_normal'))
        error('praxo:AGENT_POLICY_DENIED', 'review action outside scope');
    end
    value = praxo.json_make_object({ ...
        'review_id', praxo.json_make_string('vibration-100'); ...
        'action', praxo.json_make_string(action.value); ...
        'status', praxo.json_make_string('draft_only'); ...
        'review_required', praxo.json_make_bool(true); ...
        'equipment_commands', praxo.json_make_number(0)});
end

function allowed = authorize(action, region)
    allowed = false;
    if strcmp(action.kind, 'model.generate')
        allowed = true;
    elseif strcmp(action.kind, 'tool.invoke')
        [scope, found] = praxo.json_field(action.arguments, 'region');
        if ~found || ~strcmp(scope.value, region) || ~strcmp(region, 'region-100')
            allowed = false;
        elseif strcmp(action.toolName, 'analyze_vibration')
            allowed = true;
        elseif strcmp(action.toolName, 'draft_review')
            [choice, choiceFound] = praxo.json_field(action.arguments, 'action');
            allowed = choiceFound && ...
                (strcmp(choice.value, 'review_inspection') || strcmp(choice.value, 'review_normal'));
        end
    end
end
