function test_toolcall()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
vectors = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'toolcall.json')));
vectors = field(vectors, 'vectors').value;
for i = 1:numel(vectors)
    vector = vectors{i};
    input = field(vector, 'input');
    expect = field(vector, 'expect');
    content = field(input, 'content').value;
    if strcmp(field(input, 'operation').value, 'strip')
        assert(strcmp(praxo.strip_tool_call_markup(content), field(expect, 'text').value));
    else
        call = praxo.parse_tool_call(content);
        if has_field(expect, 'nil')
            assert(isempty(call));
        else
            assert(strcmp(call.name, field(expect, 'name').value));
            assert(isequal(call.input, field(expect, 'input')));
        end
    end
end
call = praxo.parse_tool_call('<tool_call name="first">{}</tool_call><tool_call name="last">{"a":[true,null,{"x":1}]}</tool_call>');
assert(strcmp(call.name, 'last'));
assert(strcmp(praxo.encode_json(call.input), '{"a":[true,null,{"x":1}]}'));
call = praxo.parse_tool_call('{"name":"x"}');
assert(strcmp(praxo.encode_json(call.input), '{}'));
assert(isempty(praxo.parse_tool_call('{"name":"x","input":[]}')));
assert(isempty(praxo.parse_tool_call('<tool_call name="x">[1]</tool_call>')));
assert(isempty(praxo.parse_tool_call('echo {}')));
assert(isempty(praxo.parse_tool_call('<x.y>{bad}</x.y>')));
assert(isempty(praxo.parse_tool_call('<a.one>{}</a.one><b.two>{bad}</b.two>')));
call = praxo.parse_tool_call('{"name":"x","input":{},"risk":"high","idempotency_key":"k"}');
assert(strcmp(call.metadata.risk, 'high') && strcmp(call.metadata.idempotency_key, 'k'));
assert(isempty(praxo.parse_tool_call('{"name":"x","input":{},"risk":42}')));
try
    praxo.parse_tool_call(repmat('x', 1, 262145));
    error('test:failure', 'Expected bounded input error');
catch err
    assert(strcmp(err.identifier, 'praxo:toolcall'));
end
call = praxo.parse_tool_call('<fs.read>{"path":"C:\query\file"}</fs.read>');
assert(strcmp(call.input.value{1, 2}.value, 'C:\query\file'));
assert(strcmp(praxo.strip_tool_call_markup(' a <x.y>{"x":1}</x.y> b '), 'a  b'));
assert(strcmp(praxo.strip_tool_call_markup('a<tool_call name="x">unfinished'), 'a'));
assert(strcmp(praxo.strip_tool_call_markup(sprintf(' a\n\n\n\nb ')), sprintf('a\n\nb')));
assert(strcmp(praxo.strip_tool_call_markup('x.y {}'), 'x.y {}'));
disp('test_toolcall passed');
end

function value = field(node, key)
index = find(strcmp(node.value(:, 1), key), 1, 'last');
assert(~isempty(index));
value = node.value{index, 2};
end

function result = has_field(node, key)
result = any(strcmp(node.value(:, 1), key));
end
