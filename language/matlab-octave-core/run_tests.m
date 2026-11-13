function run_tests()
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
implementation = fullfile(root, 'language', 'matlab-octave-core');
addpath(implementation);
addpath(fullfile(implementation, 'tests'));
spec = strtrim(fileread(fullfile(root, 'spec', 'SPEC_VERSION')));
assert(strcmp(spec, '0.2.0'));
groups = {'toolcall', 'jsonschema', 'plugin', 'memory', 'event', 'stream', ...
    'checkpoint', 'policy', 'context', 'middleware', 'agent-loop'};
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
test_memory();
test_event();
test_harmovela();
test_stream();
test_checkpoint();
test_policy();
test_context();
test_middleware();
test_agent();
test_openai();
test_provider_adapters();
test_mcp();
test_otel();
test_retriever();
test_delegation();
disp('All declared MATLAB/Octave Core vector groups passed');
end

function value = field_value(node, key)
index = find(strcmp(node.value(:, 1), key), 1, 'last');
assert(~isempty(index));
value = node.value{index, 2};
end
