function water_quality()
    args = argv();
    if any(strcmp(args, '--test'))
        run_tests();
        return;
    end
    low = ~any(strcmp(args, '--normal'));
    failure = any(strcmp(args, '--simulate-failure'));
    [result, reads, drafts] = run_review('pond-100', low, failure);
    if ~isempty(result.errorCode)
        fprintf(stderr, 'water quality failed: reads=%d drafts=%d; %s\n', reads, drafts, result.errorCode);
        exit(1);
    end
    fprintf('%s\n', result.output);
end

function run_tests()
    [result, reads, drafts] = run_review('pond-100', true, false);
    assert(isempty(result.errorCode) && reads == 1 && drafts == 1);
    report = praxo.parse_json(result.output);
    [water, waterFound] = praxo.json_field(report, 'water');
    [flagged, flagFound] = praxo.json_field(water, 'low_oxygen');
    [review, reviewFound] = praxo.json_field(report, 'review');
    [action, actionFound] = praxo.json_field(review, 'action');
    assert(waterFound && flagFound && flagged.value == true);
    assert(reviewFound && actionFound && strcmp(action.value, 'review_aeration'));

    [normal, normalReads, normalDrafts] = run_review('pond-100', false, false);
    assert(isempty(normal.errorCode) && normalReads == 1 && normalDrafts == 1);
    normalReport = praxo.parse_json(normal.output);
    [normalWater, normalWaterFound] = praxo.json_field(normalReport, 'water');
    [normalFlag, normalFlagFound] = praxo.json_field(normalWater, 'low_oxygen');
    [normalReview, normalReviewFound] = praxo.json_field(normalReport, 'review');
    [normalAction, normalActionFound] = praxo.json_field(normalReview, 'action');
    assert(normalWaterFound && normalFlagFound && normalFlag.value == false);
    assert(normalReviewFound && normalActionFound && strcmp(normalAction.value, 'review_normal'));

    [denied, deniedReads, deniedDrafts] = run_review('pond-200', true, false);
    assert(strcmp(denied.errorCode, 'AGENT_POLICY_DENIED'));
    assert(deniedReads == 0 && deniedDrafts == 0);

    [failed, failedReads, failedDrafts] = run_review('pond-100', true, true);
    assert(strcmp(failed.errorCode, 'TOOL_ERROR'));
    assert(failedReads == 1 && failedDrafts == 0);

    fprintf('Octave water-quality tutorial: threshold branch, denial and failure passed\n');
end

function [result, reads, drafts] = run_review(pond, low, simulateFailure)
    state = containers.Map('KeyType', 'char', 'ValueType', 'double');
    state('reads') = 0;
    state('drafts') = 0;
    model = @(request) fixture_model(request, pond, state);
    analyze = struct('name', 'analyze_water', ...
        'description', 'Compute fixed dissolved oxygen and temperature indicators; no actuator access.', ...
        'invoke', @(arguments) analyze_invoke(arguments, state, simulateFailure, low));
    draft = struct('name', 'draft_review', ...
        'description', 'Draft a review-only aeration action; never commands equipment.', ...
        'invoke', @(arguments) draft_invoke(arguments, state));
    options = praxo.agent_options(model);
    options.tools = {analyze, draft};
    options.allowedTools = {'analyze_water', 'draft_review'};
    options.toolSelection = {'analyze_water', 'draft_review'};
    options.maxSteps = 4;
    options.policy = @authorize;
    options.requirePolicy = true;
    options.requireToolScope = true;
    result = praxo.agent_run('Analyze fixed pond water and draft a review-only action.', ...
                             model, options.tools, options);
    reads = state('reads');
    drafts = state('drafts');
end

function response = fixture_model(request, pond, state)
    tools = {};
    for i = 1:numel(request.messages)
        if strcmp(request.messages{i}.role, 'tool')
            tools{end + 1} = request.messages{i};
        end
    end
    if isempty(tools)
        arguments = praxo.json_make_object({'pond', praxo.json_make_string(pond)});
        call = struct('id', 'water-1', 'name', 'analyze_water', 'arguments', arguments);
        response = struct('content', '', 'toolCalls', {{call}});
        return;
    end
    evidence = praxo.parse_json(tools{1}.content);
    if numel(tools) == 1
        [flagNode, flagFound] = praxo.json_field(evidence, 'low_oxygen');
        flagged = flagFound && flagNode.value;
        action = 'review_normal';
        if flagged, action = 'review_aeration'; end
        arguments = praxo.json_make_object({ ...
            'pond', praxo.json_make_string(pond); ...
            'action', praxo.json_make_string(action)});
        call = struct('id', 'review-1', 'name', 'draft_review', 'arguments', arguments);
        response = struct('content', '', 'toolCalls', {{call}});
        return;
    end
    review = praxo.parse_json(tools{end}.content);
    report = praxo.json_make_object({ ...
        'stage', praxo.json_make_string('water_reviewed'); ...
        'water', evidence; ...
        'review', review; ...
        'aerator_commands', praxo.json_make_number(0)});
    response = struct('content', praxo.encode_json(report));
end

function value = analyze_invoke(arguments, state, simulateFailure, low)
    state('reads') = state('reads') + 1;
    [pond, found] = praxo.json_field(arguments, 'pond');
    if ~found || ~strcmp(pond.value, 'pond-100')
        error('praxo:AGENT_POLICY_DENIED', 'pond outside fixture');
    end
    if simulateFailure
        error('praxo:TOOL_ERROR', 'simulated pond data unavailable');
    end
    oxygen = 6.2;
    if low, oxygen = 4.2; end
    threshold = 5.0;
    value = praxo.json_make_object({ ...
        'pond', praxo.json_make_string('pond-100'); ...
        'dissolved_oxygen', praxo.json_make_number(oxygen); ...
        'temperature_c', praxo.json_make_number(27.5); ...
        'oxygen_threshold', praxo.json_make_number(threshold); ...
        'low_oxygen', praxo.json_make_bool(oxygen < threshold); ...
        'source', praxo.json_make_string('water_fixture')});
end

function value = draft_invoke(arguments, state)
    state('drafts') = state('drafts') + 1;
    [pond, found] = praxo.json_field(arguments, 'pond');
    [action, actionFound] = praxo.json_field(arguments, 'action');
    if ~found || ~strcmp(pond.value, 'pond-100') || ~actionFound || ...
       ~(strcmp(action.value, 'review_aeration') || strcmp(action.value, 'review_normal'))
        error('praxo:AGENT_POLICY_DENIED', 'review action outside scope');
    end
    value = praxo.json_make_object({ ...
        'review_id', praxo.json_make_string('water-100'); ...
        'action', praxo.json_make_string(action.value); ...
        'status', praxo.json_make_string('draft_only'); ...
        'review_required', praxo.json_make_bool(true); ...
        'aerator_commands', praxo.json_make_number(0)});
end

function allowed = authorize(action)
    allowed = false;
    if strcmp(action.kind, 'model.generate')
        allowed = true;
    elseif strcmp(action.kind, 'tool.invoke')
        [pond, found] = praxo.json_field(action.arguments, 'pond');
        if ~found || ~strcmp(pond.value, 'pond-100')
            allowed = false;
        elseif strcmp(action.toolName, 'analyze_water')
            allowed = true;
        elseif strcmp(action.toolName, 'draft_review')
            [choice, choiceFound] = praxo.json_field(action.arguments, 'action');
            allowed = choiceFound && ...
                (strcmp(choice.value, 'review_aeration') || strcmp(choice.value, 'review_normal'));
        end
    end
end
