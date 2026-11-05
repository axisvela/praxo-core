function test_event()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'event.json')));
vectors = praxo.json_field(document, 'vectors');
vectors = vectors.value;
for i = 1:numel(vectors)
    input = praxo.json_field(vectors{i}, 'input');
    expect = praxo.json_field(vectors{i}, 'expect');
    raw_events = praxo.json_field(input, 'events');
    events = cell(1, numel(raw_events.value));
    for j = 1:numel(raw_events.value)
        events{j} = struct('kind', raw_events.value{j}.value, 'sessionId', 's1', 'runId', '', ...
            'data', praxo.json_make_null());
    end
    sink_mode = 'filter';
    [mode, found] = praxo.json_field(input, 'sink');
    if found, sink_mode = mode.value; end
    if strcmp(sink_mode, 'multi')
        count = max(1, praxo.json_int(input, 'sinkCount', 1));
        sinks = cell(1, count);
        for j = 1:count, sinks{j} = praxo.event_new(); end
        sink = praxo.event_multi(sinks);
        for j = 1:numel(events), sink = praxo.event_emit(sink, events{j}); end
        per_sink = cell(1, numel(sink.sinks));
        for j = 1:numel(sink.sinks)
            per_sink{j} = strings_node(praxo.event_kinds(sink.sinks{j}));
        end
        assert(praxo.json_equal(praxo.json_make_array(per_sink), node_or(expect, 'perSink')));
    else
        predicate = {};
        [value, found] = praxo.json_field(input, 'predicateTypes');
        if found
            for j = 1:numel(value.value), predicate{j} = value.value{j}.value; end
        end
        sink = praxo.event_filter(praxo.event_new(), predicate);
        for j = 1:numel(events), sink = praxo.event_emit(sink, events{j}); end
        kinds = praxo.event_kinds(sink);
        if isempty(kinds)
            delivered = praxo.json_make_null();
        else
            delivered = strings_node(kinds);
        end
        assert(praxo.json_equal(delivered, node_or(expect, 'delivered')));
    end
end
disp('test_event passed');
end

function node = strings_node(values)
items = cell(1, numel(values));
for i = 1:numel(values), items{i} = praxo.json_make_string(values{i}); end
node = praxo.json_make_array(items);
end

function value = node_or(node, key)
[value, found] = praxo.json_field(node, key);
assert(found);
end
