function chain_example()
effects = containers.Map('KeyType', 'char', 'ValueType', 'double');
otel_spans = 0;
harmovela_events = 0;
child_calls = 0;
parent_calls = 0;

transport = @(method, params) mcp_transport(method, params, effects);
client = praxo.mcp_client(transport);
tools = praxo.mcp_list_tools(client);
assert(numel(tools) == 1);

otel = praxo.otel_sink('http://otel.local/v1/traces', 'praxo-core', {}, ...
    @(method, url, headers, body) capture_otel(body), ...
    @() struct('epochNanos', '1794294000000000000', ...
               'createdAt', '2026-11-17T00:00:00.000000000Z'));
harmovela = praxo.harmovela_sink('http://harmovela.local', 'praxo-core', '0.2', ...
    @(method, url, headers, body) capture_harmovela(body), ...
    @() struct('epochNanos', '1794294000000000000', ...
               'createdAt', '2026-11-17T00:00:00.000000000Z'));

record = struct('name', 'record', ...
    'description', 'Record a target through the MCP client', ...
    'invoke', @(arguments) praxo.mcp_call_tool(client, 'record', arguments));
delegate = struct('name', 'delegate', ...
    'description', 'Run a governed child agent with a narrowed record scope', ...
    'invoke', @delegate_invoke);

parent_model = @(request) parent_model_fn(request);
options = praxo.agent_options(parent_model);
options.tools = {record, delegate};
options.allowedTools = {'record', 'delegate'};
options.policy = @parent_policy;
options.requirePolicy = true;
options.requireToolScope = true;
options.maxSteps = 4;
parent = praxo.agent_run('record parent, then delegate', parent_model, ...
    options.tools, options);
emit_events(parent, 'chain-parent', 'run-chain');

denied_model = @(request) denied_model_fn(request);
denied_options = praxo.agent_options(denied_model);
denied_options.tools = {record};
denied_options.allowedTools = {'record'};
denied_options.policy = @parent_policy;
denied_options.requirePolicy = true;
denied_options.requireToolScope = true;
denied_options.maxSteps = 2;
denied_options.interruptOn = {'record'};
denied_options.onInterruptDecision = @decide_edit;
denied = praxo.agent_run('attempt a denied edit', denied_model, ...
    denied_options.tools, denied_options);
emit_events(denied, 'chain-denied', 'run-denied');

praxo.mcp_close(client);
parent_effect = effect_count(effects, 'parent');
child_effect = effect_count(effects, 'child');
blocked_effect = effect_count(effects, 'blocked');
fprintf('output: %s\n', parent.output);
fprintf('effects: parent=%d child=%d\n', parent_effect, child_effect);
fprintf('child calls: %d\n', child_calls);
fprintf('otel spans: %d\n', otel_spans);
fprintf('harmovela events: %d\n', harmovela_events);
fprintf('denied effects: %d\n', blocked_effect);
assert(strcmp(parent.output, 'DONE'));
assert(parent_effect == 1);
assert(child_effect == 1);
assert(child_calls == 2);
assert(otel_spans >= 3);
assert(harmovela_events >= 3);
assert(blocked_effect == 0);
assert(~isempty(denied.errorCode));

    function result = mcp_transport(method, params, effects_map)
        switch method
            case 'initialize'
                result = praxo.json_make_object({ ...
                    'protocolVersion', praxo.json_make_string('2024-11-05'); ...
                    'serverInfo', praxo.json_make_object({ ...
                        'name', praxo.json_make_string('fake-mcp')})});
            case 'tools/list'
                schema = praxo.json_make_object({ ...
                    'type', praxo.json_make_string('object'); ...
                    'properties', praxo.json_make_object({ ...
                        'target', praxo.json_make_object({ ...
                            'type', praxo.json_make_string('string')})}); ...
                    'required', praxo.json_make_array({ ...
                        praxo.json_make_string('target')})});
                tool = praxo.json_make_object({ ...
                    'name', praxo.json_make_string('record'); ...
                    'description', praxo.json_make_string('Record a target'); ...
                    'inputSchema', schema});
                result = praxo.json_make_object({ ...
                    'tools', praxo.json_make_array({tool})});
            case 'tools/call'
                [arguments, found] = praxo.json_field(params, 'arguments');
                target = '';
                if found
                    [target_value, has_target] = praxo.json_field(arguments, 'target');
                    if has_target && strcmp(target_value.kind, 'string')
                        target = target_value.value;
                    end
                end
                effects_map(target) = effect_count(effects_map, target) + 1;
                text = praxo.json_make_object({ ...
                    'type', praxo.json_make_string('text'); ...
                    'text', praxo.json_make_string(['recorded:' target])});
                result = praxo.json_make_object({ ...
                    'content', praxo.json_make_array({text})});
            otherwise
                result = praxo.json_make_object(cell(0, 2));
        end
    end

    function response = parent_model_fn(request)
        parent_calls = parent_calls + 1;
        if parent_calls == 1
            response = tool_response(record_call('parent-record', 'parent'));
        elseif parent_calls == 2
            response = tool_response(tool_call('parent-delegate', 'delegate', ...
                praxo.json_make_object({ ...
                    'task', praxo.json_make_string('record child')})));
        else
            response = struct('content', 'DONE');
        end
    end

    function response = denied_model_fn(request)
        response = tool_response(record_call('denied-record', 'edit-me'));
    end

    function response = tool_response(call)
        response = struct('content', '', 'toolCalls', {{call}});
    end

    function call = record_call(id, target)
        call = tool_call(id, 'record', praxo.json_make_object({ ...
            'target', praxo.json_make_string(target)}));
    end

    function call = tool_call(id, name, arguments)
        call = struct('id', id, 'name', name, 'arguments', arguments);
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
        emit_events(child, 'chain-child', 'run-child');
        value = praxo.json_make_string(child.output);
    end

    function response = child_model_fn(request)
        child_calls = child_calls + 1;
        if child_calls == 1
            response = tool_response(record_call('child-record', 'child'));
        else
            response = struct('content', 'DONE');
        end
    end

    function allowed = parent_policy(action)
        if strcmp(action.kind, 'model.generate')
            allowed = true;
        elseif strcmp(action.kind, 'tool.invoke') && strcmp(action.toolName, 'record')
            [target, found] = praxo.json_field(action.arguments, 'target');
            allowed = found && strcmp(target.kind, 'string') && ...
                ~strcmp(target.value, 'blocked');
        elseif strcmp(action.kind, 'tool.invoke') && strcmp(action.toolName, 'delegate')
            allowed = true;
        else
            allowed = false;
        end
    end

    function allowed = child_policy(action)
        allowed = strcmp(action.kind, 'model.generate') || ...
            (strcmp(action.kind, 'tool.invoke') && strcmp(action.toolName, 'record'));
    end

    function decision = decide_edit(interrupt)
        decision = struct('action', 'edit', 'arguments', ...
            praxo.json_make_object({ ...
                'target', praxo.json_make_string('blocked')}));
    end

    function response = capture_otel(body)
        payload = praxo.parse_json(body);
        [spans, spans_found] = praxo.json_field(payload, 'resourceSpans');
        if spans_found
            for i = 1:numel(spans.value)
                [scopes, scopes_found] = praxo.json_field(spans.value{i}, 'scopeSpans');
                if scopes_found
                    for j = 1:numel(scopes.value)
                        [entries, entries_found] = praxo.json_field(scopes.value{j}, 'spans');
                        if entries_found
                            otel_spans = otel_spans + numel(entries.value);
                        end
                    end
                end
            end
        end
        response = struct('status', 200, 'body', '');
    end

    function response = capture_harmovela(body)
        payload = praxo.parse_json(body);
        [kind, found] = praxo.json_field(payload, 'type');
        if found && strcmp(kind.kind, 'string')
            harmovela_events = harmovela_events + 1;
        end
        response = struct('status', 202, 'body', '');
    end

    function emit_events(result, session_id, run_id)
        for i = 1:numel(result.events)
            event = praxo.event(result.events{i}, session_id, run_id, ...
                praxo.json_make_null());
            otel = praxo.otel_emit(otel, event);
            harmovela = praxo.harmovela_emit(harmovela, event);
        end
    end

    function count = effect_count(effects_map, key)
        if isKey(effects_map, key)
            count = effects_map(key);
        else
            count = 0;
        end
    end
end
