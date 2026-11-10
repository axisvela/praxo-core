function sink = harmovela_emit(sink, event)
if isempty(sink.baseUrl)
    error('praxo:harmovela', 'harmovela: base URL is required');
end
source = sink.source;
if isempty(source), source = 'praxo-core'; end
spec = sink.specVersion;
if isempty(spec), spec = '0.2'; end
parts = harmovela_time(sink, event);
event_type = '';
if isfield(event, 'kind'), event_type = event.kind; end
if isfield(event, 'type'), event_type = event.type; end
prefix = 'event';
if isfield(event, 'runId') && ~isempty(event.runId)
    prefix = event.runId;
elseif isfield(event, 'sessionId') && ~isempty(event.sessionId)
    prefix = event.sessionId;
end
identifier = sprintf('%s-%s', prefix, parts.epochNanos);
envelope = praxo.json_make_object({ ...
    'spec_version', praxo.json_make_string(spec); ...
    'id', praxo.json_make_string(identifier); ...
    'type', praxo.json_make_string(event_type); ...
    'source', praxo.json_make_string(source); ...
    'created_at', praxo.json_make_string(parts.createdAt); ...
    'payload', harmovela_payload(event)});
body = praxo.encode_json(envelope);
url = [regexprep(sink.baseUrl, '/+$', '') '/events'];
headers = struct('content_type', 'application/json');
if isempty(sink.transport)
    response = harmovela_default_transport('POST', url, headers, body);
else
    response = sink.transport('POST', url, headers, body);
end
status = response.status;
if status < 200 || status >= 300
    text = response.body;
    if ~ischar(text), text = ''; end
    if numel(text) > 512, text = text(1:512); end
    error('praxo:harmovela', 'harmovela: HTTP %d: %s', status, text);
end
end

function parts = harmovela_time(sink, event)
if isfield(event, 'at') && isstruct(event.at) && ...
        isfield(event.at, 'epochNanos') && isfield(event.at, 'createdAt')
    parts = event.at;
    return;
end
if ~isempty(sink.clock)
    parts = sink.clock();
    return;
end
try
    current = time();
catch
    current = (now() - 719529) * 86400;
end
seconds = floor(current);
nanos = round((current - seconds) * 1e9);
if nanos >= 1e9
    seconds = seconds + 1;
    nanos = nanos - 1e9;
end
vector = datevec(seconds / 86400 + 719529);
parts = struct( ...
    'epochNanos', sprintf('%.0f', seconds * 1e9 + nanos), ...
    'createdAt', sprintf('%04d-%02d-%02dT%02d:%02d:%02d.%09dZ', ...
        vector(1), vector(2), vector(3), vector(4), vector(5), vector(6), nanos));
end

function payload = harmovela_payload(event)
pairs = cell(0, 2);
if isfield(event, 'data') && isstruct(event.data) && ...
        isfield(event.data, 'kind') && strcmp(event.data.kind, 'object')
    pairs = event.data.value;
end
if isfield(event, 'sessionId') && ~isempty(event.sessionId)
    pairs = harmovela_set(pairs, 'session_id', ...
        praxo.json_make_string(event.sessionId));
end
if isfield(event, 'runId') && ~isempty(event.runId)
    pairs = harmovela_set(pairs, 'run_id', ...
        praxo.json_make_string(event.runId));
end
payload = praxo.json_make_object(pairs);
end

function pairs = harmovela_set(pairs, key, value)
index = find(strcmp(pairs(:, 1), key), 1);
if isempty(index)
    pairs(end + 1, :) = {key, value};
else
    pairs{index, 2} = value;
end
end

function response = harmovela_default_transport(method, url, headers, body)
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
