function delegation_example()
effects = containers.Map('KeyType', 'char', 'ValueType', 'double');
child_calls = 0;
parent_calls = 0;

record = struct('name', 'record', ...
    'description', 'Record a target in an in-memory counter', ...
    'invoke', @record_invoke);
delegate = struct('name', 'delegate', ...
    'description', 'Run a child agent with a narrowed record scope', ...
    'invoke', @delegate_invoke);

parent_model = @(request) parent_model_fn(request);
options = praxo.agent_options(parent_model);
options.tools = {record, delegate};
options.allowedTools = {'delegate'};
options.policy = @parent_policy;
options.requirePolicy = true;
options.requireToolScope = true;
options.maxSteps = 3;
parent = praxo.agent_run('delegate', parent_model, options.tools, options);
fprintf('delegation: child recorded; parent scope enforced\n');

direct_model = @(request) record_response('direct-record', 'child');
direct_options = praxo.agent_options(direct_model);
direct_options.tools = {record, delegate};
direct_options.allowedTools = {'delegate'};
direct_options.policy = @parent_policy;
direct_options.requirePolicy = true;
direct_options.requireToolScope = true;
direct_options.maxSteps = 2;
direct = praxo.agent_run('record directly', direct_model, ...
    direct_options.tools, direct_options);
fprintf('deny: parent record blocked; child effect unchanged\n');
assert(strcmp(parent.output, 'parent done'));
assert(effect_count(effects, 'child') == 1);
assert(~isempty(direct.errorCode));

    function value = record_invoke(arguments)
        [target, found] = praxo.json_field(arguments, 'target');
        if found && strcmp(target.kind, 'string')
            effects(target.value) = effect_count(effects, target.value) + 1;
        end
        value = praxo.json_make_string('recorded');
    end

    function value = delegate_invoke(arguments)
        child_model = @(request) child_model_fn(request);
        child_options = praxo.agent_options(child_model);
        child_options.tools = {record};
        child_options.allowedTools = {'record'};
        child_options.policy = @child_policy;
        child_options.requirePolicy = true;
        child_options.requireToolScope = true;
        child_options.maxSteps = 3;
        child = praxo.agent_run('record child', child_model, ...
            child_options.tools, child_options);
        value = praxo.json_make_string(child.output);
    end

    function response = parent_model_fn(request)
        parent_calls = parent_calls + 1;
        if parent_calls == 1
            response = tool_response(tool_call('parent-delegate', 'delegate', ...
                praxo.json_make_object({ ...
                    'task', praxo.json_make_string('record child')})));
        else
            response = struct('content', 'parent done');
        end
    end

    function response = child_model_fn(request)
        child_calls = child_calls + 1;
        if child_calls == 1
            response = record_response('child-record', 'child');
        else
            response = struct('content', 'child done');
        end
    end

    function response = record_response(id, target)
        response = tool_response(tool_call(id, 'record', ...
            praxo.json_make_object({ ...
                'target', praxo.json_make_string(target)})));
    end

    function response = tool_response(call)
        response = struct('content', '', 'toolCalls', {{call}});
    end

    function call = tool_call(id, name, arguments)
        call = struct('id', id, 'name', name, 'arguments', arguments);
    end

    function allowed = parent_policy(action)
        if strcmp(action.kind, 'model.generate')
            allowed = true;
        elseif strcmp(action.kind, 'tool.invoke')
            allowed = strcmp(action.toolName, 'delegate');
        else
            allowed = false;
        end
    end

    function allowed = child_policy(action)
        allowed = strcmp(action.kind, 'model.generate') || ...
            (strcmp(action.kind, 'tool.invoke') && strcmp(action.toolName, 'record'));
    end

    function count = effect_count(effects_map, key)
        if isKey(effects_map, key)
            count = effects_map(key);
        else
            count = 0;
        end
    end
end
