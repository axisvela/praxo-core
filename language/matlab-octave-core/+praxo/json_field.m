function [value, found] = json_field(node, key)
value = [];
found = false;
if ~isstruct(node) || ~isscalar(node) || ~isfield(node, 'kind') || ~strcmp(node.kind, 'object')
    return;
end
index = find(strcmp(node.value(:, 1), key), 1, 'last');
if ~isempty(index)
    value = node.value{index, 2};
    found = true;
end
end
