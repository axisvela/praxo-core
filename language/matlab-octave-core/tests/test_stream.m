function test_stream()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'stream.json')));
vectors = praxo.json_field(document, 'vectors');
for i = 1:numel(vectors.value)
    expect = praxo.json_field(vectors.value{i}, 'expect');
    expected = praxo.json_field(expect, 'kinds');
    kinds = praxo.stream_kinds();
    items = cell(1, numel(kinds));
    for j = 1:numel(kinds)
        items{j} = praxo.json_make_string(kinds{j});
    end
    assert(praxo.json_equal(praxo.json_make_array(items), expected));
end
disp('test_stream passed');
end
