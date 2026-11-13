function test_otel()
calls = {};
    function response = capture(method, url, headers, body)
        calls{end + 1} = struct('method', method, 'url', url, ...
            'headers', headers, 'body', body);
        response = struct('status', 200, 'body', '');
    end
clock = @() struct('epochNanos', '1794294000000000000', ...
    'createdAt', '2026-11-10T07:00:00.000000000Z');
data = praxo.json_make_object({ ...
    'name', praxo.json_make_string('echo'); ...
    'secret', praxo.json_make_string('hidden')});
event = praxo.event('tool.call', 's1', 'run-123', data);
sink = praxo.otel_sink('https://otel.test/v1/traces', 'checkout', {'name'}, @capture, clock);
sink = praxo.otel_emit(sink, event);
assert(numel(calls) == 1);
call = calls{1};
assert(strcmp(call.method, 'POST'));
assert(strcmp(call.url, 'https://otel.test/v1/traces'));
assert(strcmp(call.headers.content_type, 'application/json'));
payload = praxo.parse_json(call.body);
trace_id = span_text(payload, 'traceId');
span_id = span_text(payload, 'spanId');
assert(is_hex(trace_id, 32));
assert(is_hex(span_id, 16));
assert(strcmp(span_text(payload, 'name'), 'praxo.tool.call'));
assert(strcmp(span_text(payload, 'startTimeUnixNano'), '1794294000000000000'));
assert(strcmp(span_text(payload, 'endTimeUnixNano'), '1794294000000000000'));
span = first_span(payload);
assert(strcmp(attribute_value(span, 'praxo.event.type'), 'tool.call'));
assert(strcmp(attribute_value(span, 'praxo.session.id'), 's1'));
assert(strcmp(attribute_value(span, 'praxo.run.id'), 'run-123'));
assert(strcmp(attribute_value(span, 'praxo.event.at'), '1794294000000000000'));
assert(strcmp(attribute_value(span, 'praxo.event.data.name'), 'echo'));
assert(~strcmp(attribute_value(span, 'praxo.event.data.secret'), 'hidden'));
assert(strcmp(resource_service(payload), 'checkout'));
assert(strcmp(scope_name(payload), 'praxo-core'));

calls = {};
sink = praxo.otel_emit(sink, event);
repeat = praxo.parse_json(calls{1}.body);
assert(strcmp(span_text(repeat, 'traceId'), trace_id));
assert(strcmp(span_text(repeat, 'spanId'), span_id));

calls = {};
excluded_sink = praxo.otel_sink('https://otel.test/v1/traces', 'checkout', {}, @capture, clock);
excluded_sink = praxo.otel_emit(excluded_sink, event);
excluded = first_span(praxo.parse_json(calls{1}.body));
assert(isempty(attribute_value(excluded, 'praxo.event.data.name')));
assert(isempty(attribute_value(excluded, 'praxo.event.data.secret')));

for status = [200, 201, 204, 299]
    accepted = praxo.otel_sink('https://otel.test/v1/traces', 'checkout', {}, ...
        @(m, u, h, b) struct('status', status, 'body', ''), clock);
    accepted = praxo.otel_emit(accepted, event);
end

caught = false;
try
    praxo.otel_emit(praxo.otel_sink('   ', 'checkout', {}, @capture, clock), event);
catch err
    caught = true;
    assert(~isempty(strfind(err.message, 'OTEL_URL')));
end
assert(caught);

body = repmat('collector down ', 1, 100);
caught = false;
try
    failing = praxo.otel_sink('https://otel.test/v1/traces', 'checkout', {}, ...
        @(m, u, h, b) struct('status', 503, 'body', body), clock);
    praxo.otel_emit(failing, event);
catch err
    caught = true;
    assert(~isempty(strfind(err.message, 'OTEL_HTTP')));
    assert(~isempty(strfind(err.message, '503')));
    assert(~isempty(strfind(err.message, 'collector down')));
    assert(numel(err.message) <= 600);
end
assert(caught);
disp('test_otel passed');
end

function span = first_span(payload)
resource_spans = field_value(payload, 'resourceSpans');
resource_span = resource_spans.value{1};
scope_spans = field_value(resource_span, 'scopeSpans');
spans = field_value(scope_spans.value{1}, 'spans');
span = spans.value{1};
end

function text = span_text(payload, key)
text = field_text(first_span(payload), key);
end

function name = resource_service(payload)
resource_spans = field_value(payload, 'resourceSpans');
resource = field_value(resource_spans.value{1}, 'resource');
name = attribute_value(resource, 'service.name');
end

function name = scope_name(payload)
resource_spans = field_value(payload, 'resourceSpans');
scope_spans = field_value(resource_spans.value{1}, 'scopeSpans');
scope = field_value(scope_spans.value{1}, 'scope');
name = field_text(scope, 'name');
end

function text = attribute_value(node, wanted)
text = '';
attributes = field_value(node, 'attributes');
for i = 1:numel(attributes.value)
    item = attributes.value{i};
    key = field_text(item, 'key');
    if strcmp(key, wanted)
        value = field_value(item, 'value');
        text = field_text(value, 'stringValue');
        return;
    end
end
end

function ok = is_hex(text, length)
ok = ischar(text) && numel(text) == length;
if ~ok, return; end
for i = 1:numel(text)
    if isempty(strfind('0123456789abcdef', text(i)))
        ok = false;
        return;
    end
end
end

function value = field_value(node, key)
[value, found] = praxo.json_field(node, key);
assert(found);
end

function text = field_text(node, key)
value = field_value(node, key);
assert(strcmp(value.kind, 'string'));
text = value.value;
end
