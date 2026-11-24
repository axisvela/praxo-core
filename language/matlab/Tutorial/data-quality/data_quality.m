function data_quality()
    args = argv();
    if any(strcmp(args, '--test'))
        run_tests();
        return;
    end
    clean = any(strcmp(args, '--normal'));
    failure = any(strcmp(args, '--simulate-failure'));
    [result, reads, drafts] = run_review('dataset-100', clean, failure);
    if ~isempty(result.errorCode)
        fprintf(stderr, 'data quality failed: reads=%d drafts=%d; %s\n', reads, drafts, result.errorCode);
        exit(1);
    end
    fprintf('%s\n', result.output);
end

function run_tests()
    [result, reads, drafts] = run_review('dataset-100', false, false);
    assert(isempty(result.errorCode) && reads == 1 && drafts == 1);
    report = praxo.parse_json(result.output);
    [metrics, metricsFound] = praxo.json_field(report, 'dataset');
    [outliers, outliersFound] = praxo.json_field(metrics, 'outliers');
    [review, reviewFound] = praxo.json_field(report, 'review');
    [action, actionFound] = praxo.json_field(review, 'action');
    assert(metricsFound && outliersFound && outliers.value == 1);
    assert(reviewFound && actionFound && strcmp(action.value, 'review_outliers'));

    [clean, cleanReads, cleanDrafts] = run_review('dataset-100', true, false);
    assert(isempty(clean.errorCode) && cleanReads == 1 && cleanDrafts == 1);
    cleanReport = praxo.parse_json(clean.output);
    [cleanMetrics, cleanMetricsFound] = praxo.json_field(cleanReport, 'dataset');
    [cleanOutliers, cleanOutliersFound] = praxo.json_field(cleanMetrics, 'outliers');
    [cleanReview, cleanReviewFound] = praxo.json_field(cleanReport, 'review');
    [cleanAction, cleanActionFound] = praxo.json_field(cleanReview, 'action');
    assert(cleanMetricsFound && cleanOutliersFound && cleanOutliers.value == 0);
    assert(cleanReviewFound && cleanActionFound && strcmp(cleanAction.value, 'review_normal'));

    [denied, deniedReads, deniedDrafts] = run_review('dataset-200', false, false);
    assert(strcmp(denied.errorCode, 'AGENT_POLICY_DENIED'));
    assert(deniedReads == 0 && deniedDrafts == 0);

    [failed, failedReads, failedDrafts] = run_review('dataset-100', false, true);
    assert(strcmp(failed.errorCode, 'TOOL_ERROR'));
    assert(failedReads == 1 && failedDrafts == 0);

    fprintf('MATLAB/Octave data-quality tutorial: statistics, branches, denial and failure passed\n');
end

function [result, reads, drafts] = run_review(dataset, clean, simulateFailure)
    state = containers.Map('KeyType', 'char', 'ValueType', 'double');
    state('reads') = 0;
    state('drafts') = 0;
    model = @(request) fixture_model(request, dataset, state);
    analyze = struct('name', 'analyze_dataset', ...
        'description', 'Compute fixed data-quality statistics; no source writes.', ...
        'invoke', @(arguments) analyze_invoke(arguments, state, simulateFailure, clean));
    draft = struct('name', 'draft_review', ...
        'description', 'Draft review-only data-quality findings; never corrects data.', ...
        'invoke', @(arguments) draft_invoke(arguments, state));
    options = praxo.agent_options(model);
    options.tools = {analyze, draft};
    options.allowedTools = {'analyze_dataset', 'draft_review'};
    options.toolSelection = {'analyze_dataset', 'draft_review'};
    options.maxSteps = 4;
    options.policy = @authorize;
    options.requirePolicy = true;
    options.requireToolScope = true;
    result = praxo.agent_run('Analyze fixed data quality and draft review-only findings.', ...
                             model, options.tools, options);
    reads = state('reads');
    drafts = state('drafts');
end

function response = fixture_model(request, dataset, state)
    tools = {};
    for i = 1:numel(request.messages)
        if strcmp(request.messages{i}.role, 'tool')
            tools{end + 1} = request.messages{i};
        end
    end
    if isempty(tools)
        arguments = praxo.json_make_object({'dataset', praxo.json_make_string(dataset)});
        call = struct('id', 'stats-1', 'name', 'analyze_dataset', 'arguments', arguments);
        response = struct('content', '', 'toolCalls', {{call}});
        return;
    end
    evidence = praxo.parse_json(tools{1}.content);
    if numel(tools) == 1
        [outlierNode, outlierFound] = praxo.json_field(evidence, 'outliers');
        hasOutliers = outlierFound && outlierNode.value > 0;
        action = 'review_normal';
        if hasOutliers, action = 'review_outliers'; end
        arguments = praxo.json_make_object({ ...
            'dataset', praxo.json_make_string(dataset); ...
            'action', praxo.json_make_string(action)});
        call = struct('id', 'review-1', 'name', 'draft_review', 'arguments', arguments);
        response = struct('content', '', 'toolCalls', {{call}});
        return;
    end
    review = praxo.parse_json(tools{end}.content);
    report = praxo.json_make_object({ ...
        'stage', praxo.json_make_string('data_quality_reviewed'); ...
        'dataset', evidence; ...
        'review', review; ...
        'writes', praxo.json_make_number(0)});
    response = struct('content', praxo.encode_json(report));
end

function value = analyze_invoke(arguments, state, simulateFailure, clean)
    state('reads') = state('reads') + 1;
    [dataset, found] = praxo.json_field(arguments, 'dataset');
    if ~found || ~strcmp(dataset.value, 'dataset-100')
        error('praxo:AGENT_POLICY_DENIED', 'dataset outside fixture');
    end
    if simulateFailure
        error('praxo:TOOL_ERROR', 'simulated dataset unavailable');
    end
    samples = [10, 12, 12, 14, 100];
    if clean, samples = [10, 11, 12, 13, 14]; end
    outlierCount = sum(samples > 50);
    value = praxo.json_make_object({ ...
        'dataset', praxo.json_make_string('dataset-100'); ...
        'samples', praxo.json_make_number(numel(samples)); ...
        'mean', praxo.json_make_number(mean(samples)); ...
        'median', praxo.json_make_number(median(samples)); ...
        'outliers', praxo.json_make_number(outlierCount); ...
        'source', praxo.json_make_string('dataset_fixture')});
end

function value = draft_invoke(arguments, state)
    state('drafts') = state('drafts') + 1;
    [dataset, found] = praxo.json_field(arguments, 'dataset');
    [action, actionFound] = praxo.json_field(arguments, 'action');
    if ~found || ~strcmp(dataset.value, 'dataset-100') || ~actionFound || ...
       ~(strcmp(action.value, 'review_outliers') || strcmp(action.value, 'review_normal'))
        error('praxo:AGENT_POLICY_DENIED', 'review action outside scope');
    end
    value = praxo.json_make_object({ ...
        'review_id', praxo.json_make_string('data-quality-100'); ...
        'action', praxo.json_make_string(action.value); ...
        'status', praxo.json_make_string('draft_only'); ...
        'review_required', praxo.json_make_bool(true); ...
        'writes', praxo.json_make_number(0)});
end

function allowed = authorize(action)
    allowed = false;
    if strcmp(action.kind, 'model.generate')
        allowed = true;
    elseif strcmp(action.kind, 'tool.invoke')
        [dataset, found] = praxo.json_field(action.arguments, 'dataset');
        if ~found || ~strcmp(dataset.value, 'dataset-100')
            allowed = false;
        elseif strcmp(action.toolName, 'analyze_dataset')
            allowed = true;
        elseif strcmp(action.toolName, 'draft_review')
            [choice, choiceFound] = praxo.json_field(action.arguments, 'action');
            allowed = choiceFound && ...
                (strcmp(choice.value, 'review_outliers') || strcmp(choice.value, 'review_normal'));
        end
    end
end
