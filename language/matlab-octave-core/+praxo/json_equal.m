function result = json_equal(left, right)
result = false;
if ~isstruct(left) || ~isscalar(left) || ~isstruct(right) || ~isscalar(right) || ...
        ~isfield(left, 'kind') || ~isfield(right, 'kind') || ~strcmp(left.kind, right.kind)
    return;
end
switch left.kind
    case 'null'
        result = true;
    case 'boolean'
        result = islogical(left.value) && islogical(right.value) && left.value == right.value;
    case 'number'
        result = isnumeric(left.value) && isnumeric(right.value) && isscalar(left.value) && ...
            isscalar(right.value) && left.value == right.value;
    case 'string'
        result = ischar(left.value) && ischar(right.value) && strcmp(left.value, right.value);
    case 'array'
        result = numel(left.value) == numel(right.value);
        if result
            for i = 1:numel(left.value)
                if ~praxo.json_equal(left.value{i}, right.value{i})
                    result = false;
                    return;
                end
            end
        end
    case 'object'
        result = size(left.value, 1) == size(right.value, 1);
        if result
            for i = 1:size(left.value, 1)
                [candidate, found] = praxo.json_field(right, left.value{i, 1});
                if ~found || ~praxo.json_equal(left.value{i, 2}, candidate)
                    result = false;
                    return;
                end
            end
        end
end
end
