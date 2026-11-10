function test_harmovela()
calls = {};
    function response = capture(method, url, headers, body)
        calls{end + 1} = struct('method', method, 'url', url, ...
            'headers', headers, 'body', body);
        response = struct('status', 201, 'body', '');
    end
clock = @() struct('epochNanos', '1794294000000000000', ...
    'createdAt', '2026-11-10T07:00:00.000000000Z');
data = praxo.json_make_object({'name', praxo.json_make_string('echo')});
event = praxo.event('tool.call', 's1', 'run-123', data);
sink = praxo.harmovela_sink('http://harmovela.test/aep/api/', ...
    'praxo-core', '0.2', @capture, clock);
sink = praxo.harmovela_emit(sink, event);
assert(numel(calls) == 1);
call = calls{1};
assert(strcmp(call.method, 'POST'));
assert(strcmp(call.url, 'http://harmovela.test/aep/api/events'));
assert(strcmp(call.headers.content_type, 'application/json'));
envelope = praxo.parse_json(call.body);
assert(strcmp(text_field(envelope, 'spec_version'), '0.2'));
assert(strcmp(text_field(envelope, 'id'), 'run-123-1794294000000000000'));
assert(strcmp(text_field(envelope, 'type'), 'tool.call'));
assert(strcmp(text_field(envelope, 'source'), 'praxo-core'));
assert(strcmp(text_field(envelope, 'created_at'), ...
    '2026-11-10T07:00:00.000000000Z'));
payload = field_value(envelope, 'payload');
assert(strcmp(text_field(payload, 'name'), 'echo'));
assert(strcmp(text_field(payload, 'session_id'), 's1'));
assert(strcmp(text_field(payload, 'run_id'), 'run-123'));

calls = {};
merged_data = praxo.json_make_object({ ...
    'name', praxo.json_make_string('echo'); ...
    'session_id', praxo.json_make_string('event-side'); ...
    'run_id', praxo.json_make_string('old')});
merged = praxo.event('tool.call', 's1', '', merged_data);
custom = praxo.harmovela_sink('http://harmovela.test', ...
    'custom', '0.3', @capture, clock);
custom = praxo.harmovela_emit(custom, merged);
merged_envelope = praxo.parse_json(calls{1}.body);
assert(strcmp(text_field(merged_envelope, 'source'), 'custom'));
assert(strcmp(text_field(merged_envelope, 'spec_version'), '0.3'));
assert(strncmp(text_field(merged_envelope, 'id'), 's1-', 3));
merged_payload = field_value(merged_envelope, 'payload');
assert(strcmp(text_field(merged_payload, 'session_id'), 's1'));
assert(strcmp(text_field(merged_payload, 'run_id'), 'old'));

for status = [200, 201, 204, 299]
    accepted = praxo.harmovela_sink('http://harmovela.test', ...
        'praxo-core', '0.2', ...
        @(m, u, h, b) struct('status', status, 'body', ''), clock);
    accepted = praxo.harmovela_emit(accepted, event);
end

body = repmat('service down ', 1, 100);
caught = false;
try
    failing = praxo.harmovela_sink('http://harmovela.test', ...
        'praxo-core', '0.2', ...
        @(m, u, h, b) struct('status', 503, 'body', body), clock);
    praxo.harmovela_emit(failing, event);
catch err
    caught = true;
    assert(~isempty(strfind(err.message, '503')));
    assert(~isempty(strfind(err.message, 'service down')));
    assert(numel(err.message) <= 600);
end
assert(caught);
disp('test_harmovela passed');
end

function value = field_value(node, key)
[value, found] = praxo.json_field(node, key);
assert(found);
end

function text = text_field(node, key)
value = field_value(node, key);
assert(strcmp(value.kind, 'string'));
text = value.value;
end
