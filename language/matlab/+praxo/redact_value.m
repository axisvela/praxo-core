function value = redact_value(value)
if ~isstruct(value) || ~isscalar(value) || ~isfield(value, 'kind')
    return;
end
switch value.kind
    case 'string'
        value.value = praxo.pii_redact(value.value);
    case 'array'
        for i = 1:numel(value.value)
            value.value{i} = praxo.redact_value(value.value{i});
        end
    case 'object'
        for i = 1:size(value.value, 1)
            value.value{i, 2} = praxo.redact_value(value.value{i, 2});
        end
end
end
