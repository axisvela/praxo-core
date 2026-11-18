function governance_example()
gov = struct('effects', containers.Map('KeyType', 'char', 'ValueType', 'double'), ...
    'budget', 0, 'children', 0);

scope_model = model_for('write', 'escape');
scope = run_child(scope_model, config({'record'}, @permissive_record));
assert(strcmp(scope.status, 'failed'));
assert(effect_count(gov.effects, 'escape') == 0);

policy_model = model_for('record', 'blocked');
composed = run_child(policy_model, config({'record'}, @composed_policy));
assert(strcmp(composed.status, 'failed'));
assert(effect_count(gov.effects, 'blocked') == 0);

gov.budget = 1;
sibling_model = model_for('record', 'sibling');
budget_config = config({'record'}, @permissive_record);
budget_config.useBudget = true;
first = run_child(sibling_model, budget_config);
second = run_child(sibling_model, budget_config);
assert(strcmp(first.status, 'completed'));
assert(strcmp(second.status, 'denied'));
assert(strcmp(second.error, 'BUDGET_EXHAUSTED'));
assert(effect_count(gov.effects, 'sibling') == 1);

limit_model = model_for('record', 'limit');
limit_config = config({'record'}, @permissive_record);
limit_config.maxChildren = 1;
limit_config.useChildren = true;
first_limit = run_child(limit_model, limit_config);
second_limit = run_child(limit_model, limit_config);
deep_config = limit_config;
deep_config.depth = 2;
deep_config.maxDepth = 1;
deep = run_child(limit_model, deep_config);
assert(strcmp(first_limit.status, 'completed'));
assert(strcmp(second_limit.error, 'CHILD_LIMIT'));
assert(strcmp(deep.error, 'DEPTH_LIMIT'));
assert(effect_count(gov.effects, 'limit') == 1);

cancel_model = model_for('record', 'cancel');
cancel_config = config({'record'}, @permissive_record);
cancel_config.cancelled = true;
cancelled = run_child(cancel_model, cancel_config);
assert(strcmp(cancelled.status, 'cancelled'));
assert(effect_count(gov.effects, 'cancel') == 0);

edit_model = model_for('record', 'edit-me');
edit_config = config({'record'}, @parent_blocked);
edit_config.editToBlocked = true;
edited = run_child(edit_model, edit_config);
assert(strcmp(edited.status, 'failed'));
assert(effect_count(gov.effects, 'edit-me') == 0);
assert(effect_count(gov.effects, 'blocked') == 0);

fprintf('MATLAB/Octave advanced delegation governance: 6/6 passed\n');

    function value = config(allowed, policy)
        value = struct('allowed', {allowed}, 'policy', policy, ...
            'depth', 0, 'maxDepth', -1, 'maxChildren', -1, ...
            'useBudget', false, 'useChildren', false, ...
            'cancelled', false, 'editToBlocked', false);
    end

    function model = model_for(tool, target)
        model = @(request) model_fn(request, tool, target);
    end

    function response = model_fn(request, tool, target)
        last = request.messages{end};
        if strcmp(last.role, 'tool')
            response = struct('content', 'done');
            return;
        end
        call = struct('id', 'call-1', 'name', tool, 'arguments', ...
            praxo.json_make_object({ ...
                'target', praxo.json_make_string(target)}));
        response = struct('content', '', 'toolCalls', {{call}});
    end

    function task = run_child(model, config_value)
        if config_value.cancelled
            task = denied_task('cancelled', 'CANCELLED');
            return;
        end
        if config_value.maxDepth >= 0 && config_value.depth > config_value.maxDepth
            task = denied_task('denied', 'DEPTH_LIMIT');
            return;
        end
        if config_value.maxChildren >= 0 && gov.children >= config_value.maxChildren
            task = denied_task('denied', 'CHILD_LIMIT');
            return;
        end
        if config_value.useBudget && gov.budget <= 0
            task = denied_task('denied', 'BUDGET_EXHAUSTED');
            return;
        end
        if config_value.useChildren
            gov.children = gov.children + 1;
        end
        tools = {tool('record'), tool('write')};
        options = praxo.agent_options(model);
        options.tools = tools;
        options.allowedTools = config_value.allowed;
        options.policy = config_value.policy;
        options.requirePolicy = true;
        options.requireToolScope = true;
        options.maxSteps = 3;
        if config_value.editToBlocked
            options.interruptOn = {'record'};
            options.onInterruptDecision = @decide_edit;
        end
        runner = @(request) run_child_agent(options);
        task = praxo.subagent_run(runner, praxo.subagent_request( ...
            'governance-parent', 'governance-child', 'run child'));
        if config_value.useBudget && strcmp(task.status, 'completed')
            gov.budget = gov.budget - 1;
        end
    end

    function result = run_child_agent(options)
        output = praxo.agent_run('run child', options.model, options.tools, options);
        result = praxo.subagent_result('child', 'child', output.output);
        if ~isempty(output.errorCode)
            error('praxo:AGENT_POLICY_DENIED', output.errorCode);
        end
    end

    function value = tool(name)
        value = struct('name', name, 'description', name, 'invoke', @effect_invoke);
    end

    function value = effect_invoke(arguments)
        [target, found] = praxo.json_field(arguments, 'target');
        if found && strcmp(target.kind, 'string')
            gov.effects(target.value) = effect_count(gov.effects, target.value) + 1;
        end
        value = praxo.json_make_string('ok');
    end

    function allowed = permissive_record(action)
        allowed = strcmp(action.kind, 'model.generate') || ...
            (strcmp(action.kind, 'tool.invoke') && strcmp(action.toolName, 'record'));
    end

    function allowed = parent_blocked(action)
        if strcmp(action.kind, 'model.generate')
            allowed = true;
        elseif strcmp(action.kind, 'tool.invoke') && strcmp(action.toolName, 'record')
            [target, found] = praxo.json_field(action.arguments, 'target');
            allowed = found && strcmp(target.kind, 'string') && ~strcmp(target.value, 'blocked');
        else
            allowed = false;
        end
    end

    function allowed = composed_policy(action)
        allowed = parent_blocked(action) && permissive_record(action);
    end

    function decision = decide_edit(interrupt)
        decision = struct('action', 'edit', 'arguments', ...
            praxo.json_make_object({ ...
                'target', praxo.json_make_string('blocked')}));
    end

    function task = denied_task(status, code)
        task = praxo.subagent_task('subagent', 'governance-parent', ...
            'governance-child', 'isolated', status, '', code, '', '');
    end

    function count = effect_count(effects_map, key)
        if isKey(effects_map, key)
            count = effects_map(key);
        else
            count = 0;
        end
    end
end
