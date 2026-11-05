function raw = encode_json(node)
raw = encode_value(node, 0);
if numel(raw) > 1048576
    error('praxo:json', 'JSON output exceeds capacity');
end
praxo.parse_json(raw);
end

function raw = encode_value(node, depth)
if depth > 64
    error('praxo:json', 'JSON nesting exceeds capacity');
end
if ~isstruct(node) || ~isscalar(node) || ~isfield(node, 'kind') || ~isfield(node, 'value') || ~ischar(node.kind) || ~isrow(node.kind)
    error('praxo:json', 'Invalid typed JSON node');
end
value = node.value;
switch node.kind
    case 'object'
        if ~iscell(value) || ndims(value) ~= 2 || size(value, 2) ~= 2
            error('praxo:json', 'Invalid object value');
        end
        parts = cell(1, size(value, 1));
        for i = 1:size(value, 1)
            parts{i} = [encode_string(value{i, 1}) ':' encode_value(value{i, 2}, depth + 1)];
        end
        raw = ['{' strjoin(parts, ',') '}'];
    case 'array'
        if ~iscell(value) || (~isvector(value) && ~isempty(value)) || ndims(value) ~= 2 || (isempty(value) && ~any(size(value) == 1) && ~isequal(size(value), [0 0]))
            error('praxo:json', 'Invalid array value');
        end
        parts = cell(1, numel(value));
        for i = 1:numel(value)
            parts{i} = encode_value(value{i}, depth + 1);
        end
        raw = ['[' strjoin(parts, ',') ']'];
    case 'string'
        raw = encode_string(value);
    case 'number'
        if ~isa(value, 'double') || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
            error('praxo:json', 'Invalid number value');
        end
        raw = sprintf('%.17g', value);
    case 'boolean'
        if ~islogical(value) || ~isscalar(value)
            error('praxo:json', 'Invalid boolean value');
        end
        if value
            raw = 'true';
        else
            raw = 'false';
        end
    case 'null'
        if ~isequal(value, [])
            error('praxo:json', 'Invalid null value');
        end
        raw = 'null';
    otherwise
        error('praxo:json', 'Unknown JSON kind');
end
end

function raw = encode_string(value)
if ~ischar(value) || (~isrow(value) && ~isempty(value))
    error('praxo:json', 'Invalid string value');
end
raw = '"';
for c = double(value)
    if c == 34 || c == 92
        raw = [raw char(92) char(c)];
    elseif c < 32
        raw = [raw sprintf('\\u%04x', c)];
    elseif c <= 255
        raw = [raw char(c)];
    else
        error('praxo:json', 'String must contain UTF-8 bytes');
    end
end
raw = [raw '"'];
end
