function test_schema()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
vectors = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'jsonschema.json')));
cases = getfield_node(vectors, 'vectors');
for i = 1:numel(cases.value)
    c = cases.value{i};
    input = getfield_node(c, 'input');
    expect = getfield_node(c, 'expect');
    paths = praxo.validate_schema(getfield_node(input, 'schema'), getfield_node(input, 'data'));
    valid = getfield_node(expect, 'valid');
    assert(isempty(paths) == valid.value);
    if ~valid.value
        expected = getfield_node(expect, 'errorPaths');
        for j = 1:numel(expected.value)
            assert(any(strcmp(paths, expected.value{j}.value)));
        end
        assert(numel(paths) == numel(expected.value));
    end
end
check('{"type":"number","minimum":0,"maximum":0}', '42', {});
check('{"type":"number","minimum":1,"maximum":3}', '4', {'$'});
check('{"type":"integer"}', '1.5', {'$'});
check('{"type":"string","minLength":2,"maxLength":2}', '"\u00e9\ud83d\ude00"', {});
check('{"type":"string","maxLength":1}', '"\u00e9\ud83d\ude00"', {'$'});
check('{"type":"object","required":["a","b"],"properties":{"a":{"type":"string"}}}', '{"a":null}', {'$.b','$.a'});
check('{"type":"array","items":{"type":"object","properties":{"x":{"type":"boolean"}}}}', '[{"x":1},{"x":true}]', {'$[0].x'});
check('{"type":"string","pattern":"^[a-z]+$"}', '"abc"', {});
check('{"type":"string","pattern":"^a+$"}', '"a\n"', {'$'});
check('{"type":"boolean","enum":[true]}', 'false', {'$'});
check('{}', 'null', {});
bad = {'[a-z]+', '^(a+)+$', '^a{2}$', '^[z-a]$', '^a|b$', '^\\d+$'};
for i = 1:numel(bad)
    s = struct('kind', 'object', 'value', {{'pattern', struct('kind', 'string', 'value', bad{i})}});
    must_fail(@() praxo.validate_schema(s, praxo.parse_json('null')));
end
must_fail(@() praxo.validate_schema(praxo.parse_json('{"type":"string","pattern":"^a+$"}'), struct('kind', 'string', 'value', repmat('a', 1, 4097))));
must_fail(@() praxo.validate_schema(praxo.parse_json('{"properties":{"x":{"pattern":"["}}}'), praxo.parse_json('{}')));
disp('test_schema passed');
end

function check(schema, data, expected)
actual = praxo.validate_schema(praxo.parse_json(schema), praxo.parse_json(data));
assert(isequal(actual, expected));
end

function value = getfield_node(node, key)
idx = find(strcmp(node.value(:, 1), key), 1, 'last');
assert(~isempty(idx));
value = node.value{idx, 2};
end

function must_fail(f)
try
    f();
catch err
    assert(strcmp(err.identifier, 'praxo:schema'));
    return;
end
error('Expected praxo:schema error');
end
