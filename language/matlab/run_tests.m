function run_tests()
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
implementation = fullfile(root, 'language', 'matlab');
addpath(implementation);
addpath(fullfile(implementation, 'tests'));
spec = strtrim(fileread(fullfile(root, 'spec', 'SPEC_VERSION')));
assert(strcmp(spec, '0.2.0'));
groups = {'toolcall', 'jsonschema', 'plugin', 'agent-loop'};
for i = 1:numel(groups)
    document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', [groups{i} '.json'])));
    assert(strcmp(field_value(document, 'specVersion').value, spec));
    assert(strcmp(field_value(document, 'group').value, groups{i}));
    cases = field_value(document, 'vectors');
    assert(strcmp(cases.kind, 'array') && ~isempty(cases.value));
end
test_json();
test_toolcall();
test_schema();
test_manifest();
test_agent();
disp('All declared Octave wire vector groups passed');
end

function value = field_value(node, key)
index = find(strcmp(node.value(:, 1), key), 1, 'last');
assert(~isempty(index));
value = node.value{index, 2};
end
