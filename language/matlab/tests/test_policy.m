function test_policy()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'policy.json')));
vectors = praxo.json_field(document, 'vectors');
for i = 1:numel(vectors.value)
    input = praxo.json_field(vectors.value{i}, 'input');
    expect = praxo.json_field(vectors.value{i}, 'expect');
    raw_grants = praxo.json_field(input, 'grants');
    grants = [];
    for j = 1:numel(raw_grants.value)
        grants(j).root = field_value(raw_grants.value{j}, 'root', '');
        grants(j).access = field_value(raw_grants.value{j}, 'access', 'read');
    end
    target = field_value(input, 'target', '');
    need = field_value(input, 'need', 'read');
    expected_error = false;
    [error_node, found] = praxo.json_field(expect, 'error');
    if found, expected_error = error_node.value; end
    if expected_error
        failed = false;
        try
            checker = praxo.path_checker(grants);
            praxo.path_check(checker, target, need);
        catch
            failed = true;
        end
        assert(failed);
    else
        checker = praxo.path_checker(grants);
        decision = praxo.path_check(checker, target, need);
        allowed = field_value(expect, 'allowed', false);
        assert(decision.allowed == allowed);
    end
end
checker = praxo.path_checker(struct('root', 'allowed', 'access', 'read'));
paths = {'../allowed/secret', '../../allowed/secret', 'x/../../allowed/secret', '..\allowed\secret'};
for i = 1:numel(paths)
    assert(~praxo.path_allowed(checker, paths{i}, 'read'));
end
assert(praxo.path_allowed(checker, 'allowed/sub/../secret', 'read'));
assert(strcmp(praxo.normalize_path('../../a/../b'), '../../b'));
assert(strcmp(praxo.normalize_path('/../../allowed'), '/allowed'));
parent = praxo.path_checker(struct('root', '../allowed', 'access', 'read'));
assert(praxo.path_allowed(parent, '../allowed/secret', 'read'));
assert(~praxo.path_allowed(parent, 'allowed/secret', 'read'));
disp('test_policy passed');
end

function value = field_value(node, key, fallback)
[item, found] = praxo.json_field(node, key);
if found, value = item.value; else, value = fallback; end
end
