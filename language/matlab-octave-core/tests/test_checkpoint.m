function test_checkpoint()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'checkpoint.json')));
vectors = praxo.json_field(document, 'vectors');
for i = 1:numel(vectors.value)
    input = praxo.json_field(vectors.value{i}, 'input');
    expect = praxo.json_field(vectors.value{i}, 'expect');
    allow = praxo.checkpoint_new();
    [registered, found] = praxo.json_field(input, 'registered');
    if found
        for j = 1:numel(registered.value)
            allow = praxo.checkpoint_register(allow, registered.value{j}.value);
        end
    end
    operation = 'roundtrip';
    [value, found] = praxo.json_field(input, 'operation');
    if found, operation = value.value; end
    kind = field_value(input, 'type', '');
    value = node_or(input, 'value', praxo.json_make_null());
    expected_code = field_value(expect, 'errorCode', '');
    switch operation
        case 'roundtrip'
            [data, code] = praxo.checkpoint_marshal(allow, kind, value);
            assert(isempty(code));
            [decoded, code] = praxo.checkpoint_unmarshal(allow, data);
            assert(isempty(code));
            assert(praxo.json_equal(decoded, node_or(expect, 'value', praxo.json_make_null())));
        case 'marshal'
            [~, code] = praxo.checkpoint_marshal(allow, kind, value);
            assert(strcmp(code, expected_code));
        case 'unmarshal'
            envelope = praxo.encode_json(praxo.json_make_object({ ...
                'type', praxo.json_make_string(kind); ...
                'data', value}));
            [~, code] = praxo.checkpoint_unmarshal(allow, envelope);
            assert(strcmp(code, expected_code));
    end
end
disp('test_checkpoint passed');
end

function value = field_value(node, key, fallback)
[item, found] = praxo.json_field(node, key);
if found, value = item.value; else, value = fallback; end
end

function value = node_or(node, key, fallback)
[value, found] = praxo.json_field(node, key);
if ~found, value = fallback; end
end
