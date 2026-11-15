function live_model_example()
    base_url = env_or('PRAXO_BASE_URL', 'http://localhost:11434/v1');
    model_name = env_or('PRAXO_MODEL', 'qwen3.5:4b');
    api_key = env_or('PRAXO_API_KEY', '');
    prompt = env_or('PRAXO_PROMPT', ...
        'What time is it? Use get_time with zone set to utc and reply with the time.');

    schema = get_time_schema();
    options = struct('baseUrl', base_url, 'model', model_name, 'apiKey', api_key, ...
        'transport', @(path, payload) http_transport(base_url, api_key, path, payload));
    model = @(request) model_call(request, options, schema);
    tool = struct('name', 'get_time', ...
        'description', 'Return the current time in ISO 8601 format for the requested zone.', ...
        'invoke', @get_time);
    agent_options = praxo.agent_options(model);
    agent_options.tools = {tool};
    agent_options.systemPrompt = ...
        'You are a concise assistant. Use the provided tools when they help.';
    agent_options.maxSteps = 4;
    agent_options.allowedTools = {'get_time'};
    agent_options.toolSelection = {'get_time'};
    agent_options.policy = @authorize;
    agent_options.requirePolicy = true;
    agent_options.requireToolScope = true;

    try
        result = praxo.agent_run(prompt, model, agent_options.tools, agent_options);
        if ~isempty(result.errorCode)
            error('praxo:live', '%s: %s', result.errorCode, result.errorMessage);
        end
        fprintf('%s\n', result.output);
    catch err
        fprintf(2, ['live model run failed: %s\n\n' ...
            'Check PRAXO_BASE_URL (%s), PRAXO_MODEL (%s), and PRAXO_API_KEY\n'], ...
            err.message, base_url, model_name);
        exit(1);
    end
end

function response = model_call(request, options, schema)
    request.tools = {struct('name', 'get_time', ...
        'description', 'Return the current time in ISO 8601 format for the requested zone.', ...
        'parameters', schema)};
    response = praxo.openai_compatible(request, options);
end

function value = get_time(arguments)
    zone = 'utc';
    [zone_node, found] = praxo.json_field(arguments, 'zone');
    if found && strcmp(zone_node.kind, 'string')
        zone = zone_node.value;
    end
    if strcmp(zone, 'local')
        value = praxo.json_make_string(datestr(now, 'yyyy-mm-ddTHH:MM:SS'));
    elseif exist('gmtime', 'builtin') || exist('gmtime', 'file')
        stamp = strftime('%Y-%m-%dT%H:%M:%S', gmtime(time()));
        value = praxo.json_make_string([stamp 'Z']);
    elseif exist('datetime', 'class') == 8
        stamp = char(datetime('now', 'TimeZone', 'UTC', ...
            'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
        value = praxo.json_make_string([stamp 'Z']);
    else
        value = praxo.json_make_string([datestr(now, 'yyyy-mm-ddTHH:MM:SS') 'Z']);
    end
end

function allowed = authorize(action)
    allowed = false;
    if strcmp(action.kind, 'model.generate')
        allowed = true;
    elseif strcmp(action.kind, 'tool.invoke')
        allowed = strcmp(action.toolName, 'get_time');
    end
end

function node = get_time_schema()
    node = praxo.json_make_object({ ...
        'type', praxo.json_make_string('object'); ...
        'properties', praxo.json_make_object({ ...
            'zone', praxo.json_make_object({ ...
                'type', praxo.json_make_string('string'); ...
                'enum', praxo.json_make_array({ ...
                    praxo.json_make_string('utc'), ...
                    praxo.json_make_string('local')}); ...
                'description', praxo.json_make_string('utc or local; defaults to utc')})})});
end

function result = http_transport(base_url, api_key, path, payload)
    url = [regexprep(base_url, '/+$', '') path];
    raw = praxo.encode_json(payload);
    input = tempname();
    output = tempname();
    fid = fopen(input, 'w');
    if fid < 0
        error('praxo:provider', 'PROVIDER_HTTP: cannot create request file');
    end
    fwrite(fid, raw, 'char');
    fclose(fid);
    header = '';
    if ~isempty(api_key)
        header = sprintf('-H "Authorization: Bearer %s" ', api_key);
    end
    command = sprintf(['curl -sS -X POST -H "Content-Type: application/json" ' ...
        '%s--data-binary "@%s" -o "%s" -w "%%{http_code}" "%s"'], ...
        header, input, output, url);
    [exit_code, status_text] = system(command);
    if exist(input, 'file') == 2
        delete(input);
    end
    body = '';
    if exist(output, 'file') == 2
        body = fileread(output);
        delete(output);
    end
    if exit_code ~= 0
        error('praxo:provider', 'PROVIDER_HTTP: curl failed (exit %d)', exit_code);
    end
    status = str2double(strtrim(status_text));
    if isnan(status)
        error('praxo:provider', 'PROVIDER_HTTP: curl returned no status');
    end
    result = struct('status', status, 'body', response_node(body));
end

function node = response_node(body)
    try
        node = praxo.parse_json(body);
    catch
        node = praxo.json_make_object({'raw', praxo.json_make_string(body)});
    end
end

function value = env_or(name, fallback)
    value = getenv(name);
    if isempty(value)
        value = fallback;
    end
end
