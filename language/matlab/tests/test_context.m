function test_context()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'context.json')));
vectors = praxo.json_field(document, 'vectors');
for i = 1:numel(vectors.value)
    input = praxo.json_field(vectors.value{i}, 'input');
    expect = praxo.json_field(vectors.value{i}, 'expect');
    raw_messages = praxo.json_field(input, 'messages');
    messages = cell(1, numel(raw_messages.value));
    for j = 1:numel(raw_messages.value)
        messages{j} = struct('role', field_value(raw_messages.value{j}, 'role', ''), ...
            'content', field_value(raw_messages.value{j}, 'content', ''));
    end
    operation = field_value(input, 'operation', '');
    if strcmp(operation, 'estimate')
        assert(praxo.estimate_tokens(messages) == field_value(expect, 'tokens', 0));
    else
        [budget_node, found] = praxo.json_field(input, 'budget');
        if ~found, budget_node = praxo.json_make_object({}); end
        budget = praxo.context_budget(praxo.json_int(budget_node, 'maxTokens', 0), ...
            praxo.json_int(budget_node, 'keepRecent', 0));
        [output, ok] = praxo.compact_context(budget, messages);
        expected_ok = field_value(expect, 'ok', true);
        assert(ok == expected_ok);
        if ok
            assert(praxo.estimate_tokens(output) == field_value(expect, 'tokens', 0));
            wire = cell(1, numel(output));
            for j = 1:numel(output), wire{j} = praxo.message_wire(output{j}); end
            expected = praxo.json_field(expect, 'messages');
            assert(praxo.json_equal(praxo.json_make_array(wire), expected));
        end
    end
end
messages = {struct('role', 'system', 'content', 'sys'), ...
    struct('role', 'user', 'content', 'message 0'), ...
    struct('role', 'user', 'content', 'message 1')};
assert(praxo.estimate_tokens(messages) == 16);
[output, ok] = praxo.compact_context(praxo.context_budget(0, 0), messages);
assert(ok && numel(output) == 3);
disp('test_context passed');
end

function value = field_value(node, key, fallback)
[item, found] = praxo.json_field(node, key);
if found, value = item.value; else, value = fallback; end
end
