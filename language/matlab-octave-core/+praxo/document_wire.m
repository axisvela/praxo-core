function node = document_wire(value)
pairs = { ...
    'id', praxo.json_make_string(value.id); ...
    'content', praxo.json_make_string(value.content)};
if isstruct(value.metadata) && ~isempty(fieldnames(value.metadata))
    names = fieldnames(value.metadata);
    metadata = cell(0, 2);
    for i = 1:numel(names)
        metadata(end + 1, :) = {names{i}, ...
            document_value(value.metadata.(names{i}))};
    end
    pairs(end + 1, :) = {'metadata', praxo.json_make_object(metadata)};
end
if value.score ~= 0
    pairs(end + 1, :) = {'score', praxo.json_make_number(value.score)};
end
node = praxo.json_make_object(pairs);
end

function node = document_value(value)
if ischar(value)
    node = praxo.json_make_string(value);
elseif islogical(value) && isscalar(value)
    node = praxo.json_make_bool(value);
elseif isnumeric(value) && isscalar(value)
    node = praxo.json_make_number(value);
else
    node = praxo.json_make_string(char(value));
end
end
