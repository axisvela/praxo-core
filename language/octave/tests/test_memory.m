function test_memory()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'memory.json')));
vectors = praxo.json_field(document, 'vectors');
vectors = vectors.value;
for i = 1:numel(vectors)
    input = praxo.json_field(vectors{i}, 'input');
    expect = praxo.json_field(vectors{i}, 'expect');
    store = praxo.memory_store();
    puts = praxo.json_field(input, 'puts');
    puts = puts.value;
    for j = 1:numel(puts)
        session_node = praxo.json_field(puts{j}, 'session');
        session = session_node.value;
        record_node = praxo.json_field(puts{j}, 'record');
        record = struct( ...
            'id', value_or(record_node, 'id', ''), ...
            'frame', value_or(record_node, 'frame', ''), ...
            'content', value_or(record_node, 'content', ''), ...
            'createdAt', node_value(record_node, 'createdAt', ''));
        store = praxo.memory_put(store, session, record);
    end
    session_node = praxo.json_field(input, 'session');
    query_node = praxo.json_field(input, 'query');
    records = praxo.memory_search(store, session_node.value, query_node.value, ...
        praxo.json_int(input, 'limit', 0));
    ids = empty_or_strings(records, 'id');
    contents = empty_or_strings(records, 'content');
    assert(praxo.json_equal(ids, node_or(expect, 'ids', praxo.json_make_null())));
    assert(praxo.json_equal(contents, node_or(expect, 'contents', praxo.json_make_null())));
end
disp('test_memory passed');
end

function node = empty_or_strings(records, field)
if isempty(records)
    node = praxo.json_make_null();
else
    items = cell(1, numel(records));
    for i = 1:numel(records), items{i} = praxo.json_make_string(records{i}.(field)); end
    node = praxo.json_make_array(items);
end
end

function value = node_or(node, key, fallback)
[value, found] = praxo.json_field(node, key);
if ~found, value = fallback; end
end

function value = node_value(node, key, fallback)
value = node_or(node, key, fallback);
if isstruct(value) && isfield(value, 'value'), value = value.value; end
end

function value = value_or(node, key, fallback)
value = node_value(node, key, fallback);
end
