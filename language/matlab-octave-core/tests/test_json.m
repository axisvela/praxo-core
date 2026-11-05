function test_json()
try
    praxo.parse_json(repmat(' ', 1, 1048577));
    error('test:failure', 'Expected input capacity error');
catch err
    assert(strcmp(err.identifier, 'praxo:json'));
end
try
    praxo.parse_json([repmat('[', 1, 66) '0' repmat(']', 1, 66)]);
    error('test:failure', 'Expected nesting capacity error');
catch err
    assert(strcmp(err.identifier, 'praxo:json'));
end
raw = '{"x":1,"x":[true,false,null,"\u0000\u00e9\ud83d\ude00"],"":{}}';
node = praxo.parse_json(raw);
assert(strcmp(node.kind, 'object'));
assert(isequal(size(node.value), [3 2]));
assert(strcmp(node.value{1, 1}, 'x') && strcmp(node.value{2, 1}, 'x'));
arr = node.value{2, 2}.value;
assert(strcmp(arr{1}.kind, 'boolean') && arr{1}.value);
assert(~arr{2}.value && strcmp(arr{3}.kind, 'null'));
assert(isequal(double(arr{4}.value), [0 195 169 240 159 152 128]));
assert(isequal(node, praxo.parse_json(praxo.encode_json(node))));
assert(strcmp(praxo.encode_json(praxo.parse_json('[]')), '[]'));
assert(strcmp(praxo.encode_json(praxo.parse_json('{}')), '{}'));
assert(strcmp(praxo.encode_json(praxo.parse_json('null')), 'null'));
number = praxo.parse_json('-1.25e+2');
assert(number.value == -125);
bad = {'', ' ', '[', '[1,]', '{"a":1,}', '{"a" 1}', '01', '-01', '1.', '1e', '1e9999', 'true false', '"\x"', '"\uD800"', '"\uDC00"', '"\uD800\u0041"', '"\u12"', char([34 10 34]), char([34 192 128 34]), char([34 237 160 128 34]), char([34 244 144 128 128 34]), char([34 226 130 34])};
for i = 1:numel(bad)
    must_fail(@() praxo.parse_json(bad{i}));
end
badnodes = {struct('kind', 'number', 'value', Inf), struct('kind', 'boolean', 'value', 1), struct('kind', 'null', 'value', 0), struct('kind', 'string', 'value', char([255])), struct('kind', 'object', 'value', {{'a'}}), struct('kind', 'other', 'value', [])};
for i = 1:numel(badnodes)
    must_fail(@() praxo.encode_json(badnodes{i}));
end
disp('test_json passed');
end

function must_fail(f)
try
    f();
catch err
    assert(strcmp(err.identifier, 'praxo:json'));
    return;
end
error('Expected praxo:json error');
end
