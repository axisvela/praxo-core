function sink = otel_emit(sink, event)
endpoint = strtrim(sink.endpoint);
if isempty(endpoint)
    error('praxo:otel', 'OTEL_URL: otel: endpoint is required');
end
stamp = clock_stamp(sink.clock);
event_type = event_name(event);
data = [];
if isfield(event, 'data'), data = event.data; end
data_text = '';
if isstruct(data) && isscalar(data) && isfield(data, 'kind')
    data_text = canonical(data);
end
session_id = '';
if isfield(event, 'sessionId') && ~isempty(event.sessionId)
    session_id = event.sessionId;
end
run_id = '';
if isfield(event, 'runId') && ~isempty(event.runId)
    run_id = event.runId;
end
key = [session_id '|' run_id '|' event_type '|' stamp '|' data_text];
trace_id = [stable_id('trace-a:' , key) stable_id('trace-b:', key) ...
    stable_id('trace-c:', key) stable_id('trace-d:', key)];
span_id = [stable_id('span-a:', key) stable_id('span-b:', key)];

attributes = {attribute('praxo.event.type', event_type)};
if ~isempty(session_id)
    attributes{end + 1} = attribute('praxo.session.id', session_id);
end
if ~isempty(run_id)
    attributes{end + 1} = attribute('praxo.run.id', run_id);
end
attributes{end + 1} = attribute('praxo.event.at', stamp);
if isstruct(data) && isscalar(data) && isfield(data, 'kind') && ...
        strcmp(data.kind, 'object') && isfield(data, 'value') && iscell(data.value)
    for i = 1:numel(sink.allowedDataKeys)
        name = sink.allowedDataKeys{i};
        if ~ischar(name), continue; end
        [value, found] = praxo.json_field(data, name);
        if found
            attributes{end + 1} = attribute(['praxo.event.data.' name], text_value(value));
        end
    end
end

span = praxo.json_make_object({ ...
    'traceId', praxo.json_make_string(trace_id); ...
    'spanId', praxo.json_make_string(span_id); ...
    'name', praxo.json_make_string(['praxo.' event_type]); ...
    'kind', praxo.json_make_number(1); ...
    'startTimeUnixNano', praxo.json_make_string(stamp); ...
    'endTimeUnixNano', praxo.json_make_string(stamp); ...
    'attributes', praxo.json_make_array(attributes)});
scope = praxo.json_make_object({ ...
    'scope', praxo.json_make_object({ ...
        'name', praxo.json_make_string('praxo-core')}); ...
    'spans', praxo.json_make_array({span})});
service = sink.serviceName;
if isempty(service), service = 'praxo-core'; end
resource = praxo.json_make_object({ ...
    'resource', praxo.json_make_object({ ...
        'attributes', praxo.json_make_array({ ...
            attribute('service.name', service)})}); ...
    'scopeSpans', praxo.json_make_array({scope})});
payload = praxo.json_make_object({ ...
    'resourceSpans', praxo.json_make_array({resource})});
body = praxo.encode_json(payload);
headers = struct('content_type', 'application/json');
if isempty(sink.transport)
    response = default_transport('POST', endpoint, headers, body);
else
    response = sink.transport('POST', endpoint, headers, body);
end
if ~isstruct(response) || ~isscalar(response) || ~isfield(response, 'status')
    error('praxo:otel', 'OTEL_HTTP: otel: transport returned an invalid response');
end
status = response.status;
if ischar(status), status = str2double(status); end
if ~isnumeric(status) || ~isscalar(status) || ~isfinite(status)
    error('praxo:otel', 'OTEL_HTTP: otel: transport returned an invalid response');
end
if status >= 200 && status < 300
    return;
end
text = '';
if isfield(response, 'body')
    text = bounded_body(response.body);
end
error('praxo:otel', 'OTEL_HTTP: otel: HTTP %d: %s', status, text);
end

function name = event_name(event)
name = '';
if isfield(event, 'kind'), name = event.kind; end
if isfield(event, 'type'), name = event.type; end
end

function text = canonical(node)
text = '';
if ~isstruct(node) || ~isscalar(node) || ~isfield(node, 'kind')
    return;
end
if strcmp(node.kind, 'object') && isfield(node, 'value') && ...
        iscell(node.value) && size(node.value, 2) == 2
    if isempty(node.value)
        text = '{}';
        return;
    end
    keys = node.value(:, 1);
    [~, order] = sort(keys);
    text = praxo.encode_json(praxo.json_make_object(node.value(order, :)));
else
    text = praxo.encode_json(node);
end
end

function text = text_value(node)
text = '';
if ~isstruct(node) || ~isscalar(node) || ~isfield(node, 'kind')
    return;
end
switch node.kind
    case 'string'
        text = node.value;
    case 'number'
        text = sprintf('%.17g', node.value);
    case 'boolean'
        if node.value
            text = 'true';
        else
            text = 'false';
        end
    case 'null'
        text = '';
    otherwise
        text = canonical(node);
end
end

function value = attribute(key, text)
value = praxo.json_make_object({ ...
    'key', praxo.json_make_string(key); ...
    'value', praxo.json_make_object({ ...
        'stringValue', praxo.json_make_string(text)})});
end

function value = stable_id(prefix, key)
text = [prefix key];
hash = uint64(2166136261);
for byte = double(text)
    hash = bitxor(hash, uint64(byte));
    hash = mod(hash * uint64(16777619), uint64(4294967296));
end
value = sprintf('%08x', uint32(hash));
end

function stamp = clock_stamp(clock)
if isempty(clock)
    seconds = (now() - 719529) * 86400;
    stamp = whole_nanos(seconds);
    return;
end
parts = clock();
if isstruct(parts) && isfield(parts, 'epochNanos')
    value = parts.epochNanos;
    if ischar(value)
        stamp = value;
    else
        stamp = sprintf('%.0f', value);
    end
    return;
end
if isstruct(parts) && isfield(parts, 'seconds')
    seconds = parts.seconds;
    nanos = 0;
    if isfield(parts, 'nanos'), nanos = parts.nanos; end
    stamp = sprintf('%.0f', floor(seconds) * 1e9 + nanos);
    return;
end
if isnumeric(parts) && isscalar(parts)
    stamp = whole_nanos(parts);
    return;
end
error('praxo:otel', 'OTEL_HTTP: otel: invalid clock');
end

function stamp = whole_nanos(seconds)
whole = floor(seconds);
fraction = round((seconds - whole) * 1e9);
if fraction >= 1e9
    whole = whole + 1;
    fraction = fraction - 1e9;
end
stamp = sprintf('%.0f', whole * 1e9 + fraction);
end

function text = bounded_body(body)
text = '';
if ischar(body)
    text = body;
elseif isstruct(body)
    try
        text = praxo.encode_json(body);
    catch
        text = '';
    end
end
if numel(text) > 512
    text = text(1:512);
end
end

function response = default_transport(method, url, headers, body)
options = weboptions('MediaType', 'application/json', ...
    'ContentType', 'json', 'RequestMethod', lower(method), 'Timeout', 30);
try
    decoded = jsondecode(body);
    webwrite(url, decoded, options);
    response = struct('status', 200, 'body', '');
catch err
    response = struct('status', 0, 'body', err.message);
end
end
