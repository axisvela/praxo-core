function paths = validate_schema(schema, data)
try
    praxo.encode_json(schema);
    praxo.encode_json(data);
catch
    error('praxo:schema', 'Invalid typed JSON node');
end
check_schema(schema);
paths = visit(schema, data, '$');
end

function check_schema(s)
if ~strcmp(s.kind, 'object')
    error('praxo:schema', 'Schema must be an object');
end
[v, found] = field(s, 'type');
if found && (~strcmp(v.kind, 'string') || ~any(strcmp(v.value, {'', 'object', 'array', 'string', 'number', 'integer', 'boolean'})))
    error('praxo:schema', 'Invalid schema type');
end
names = {'properties', 'items', 'required', 'enum', 'minLength', 'maxLength', 'minimum', 'maximum', 'pattern', 'description'};
kinds = {'object', 'object', 'array', 'array', 'number', 'number', 'number', 'number', 'string', 'string'};
for i = 1:numel(names)
    [v, found] = field(s, names{i});
    if ~found
        continue;
    end
    if ~strcmp(v.kind, kinds{i})
        error('praxo:schema', 'Invalid schema keyword');
    end
    if strcmp(names{i}, 'properties')
        for j = 1:size(v.value, 1)
            check_schema(v.value{j, 2});
        end
    elseif strcmp(names{i}, 'items')
        check_schema(v);
    elseif strcmp(names{i}, 'required')
        for j = 1:numel(v.value)
            if ~strcmp(v.value{j}.kind, 'string')
                error('praxo:schema', 'Invalid required property');
            end
        end
    elseif any(strcmp(names{i}, {'minLength', 'maxLength'}))
        if v.value ~= fix(v.value)
            error('praxo:schema', 'Invalid length');
        end
    elseif strcmp(names{i}, 'pattern') && ~isempty(v.value)
        check_pattern(v.value);
    end
end
end

function check_pattern(p)
if numel(p) > 128 || numel(p) < 2 || p(1) ~= '^' || p(end) ~= '$' || any(double(p) < 32 | double(p) > 126)
    error('praxo:schema', 'Unsupported pattern');
end
body = p(2:end-1);
if isempty(body)
    return;
end
if any(body(end) == '*+?')
    body = body(1:end-1);
    if isempty(body)
        error('praxo:schema', 'Unsupported pattern');
    end
    if body(1) ~= '[' && numel(body) ~= 1
        error('praxo:schema', 'Unsupported pattern');
    end
end
if body(1) == '['
    if numel(body) < 3 || body(end) ~= ']' || isempty(regexp(body(2:end-1), '^[a-zA-Z0-9_-]+$', 'once'))
        error('praxo:schema', 'Unsupported pattern');
    end
    chars = body(2:end-1);
    for i = 1:numel(chars)
        if chars(i) == '-' && (i == 1 || i == numel(chars) || chars(i-1) == '-' || chars(i+1) == '-' || chars(i-1) > chars(i+1))
            error('praxo:schema', 'Unsupported pattern');
        end
    end
else
    if isempty(regexp(body, '^[a-zA-Z0-9_ -]+$', 'once'))
        error('praxo:schema', 'Unsupported pattern');
    end
end
end

function paths = visit(s, data, path)
paths = {};
[t, found] = field(s, 'type');
if ~found || isempty(t.value)
    return;
end
type = t.value;
if strcmp(type, 'integer')
    valid = strcmp(data.kind, 'number') && data.value == fix(data.value);
else
    valid = strcmp(type, data.kind);
end
if ~valid
    paths = {path};
    return;
end
if strcmp(type, 'object')
    [required, found] = field(s, 'required');
    if found
        for i = 1:numel(required.value)
            key = required.value{i}.value;
            [~, present] = field(data, key);
            if ~present
                paths{end+1} = [path '.' key];
            end
        end
    end
    [props, found] = field(s, 'properties');
    if found
        for i = 1:size(props.value, 1)
            key = props.value{i, 1};
            [v, present] = field(data, key);
            if present
                paths = [paths visit(props.value{i, 2}, v, [path '.' key])];
            end
        end
    end
elseif strcmp(type, 'array')
    [items, found] = field(s, 'items');
    if found
        for i = 1:numel(data.value)
            paths = [paths visit(items, data.value{i}, [path '[' num2str(i-1) ']'])];
        end
    end
else
    [en, found] = field(s, 'enum');
    if found && ~isempty(en.value)
        matched = false;
        for i = 1:numel(en.value)
            if isequal(en.value{i}, data)
                matched = true;
                break;
            end
        end
        if ~matched
            paths{end+1} = path;
        end
    end
    if strcmp(type, 'string')
        bytes = double(data.value);
        len = sum(bytes < 128 | bytes >= 192);
        [v, found] = field(s, 'minLength');
        if found && v.value > 0 && len < v.value
            paths{end+1} = path;
        end
        [v, found] = field(s, 'maxLength');
        if found && v.value > 0 && len > v.value
            paths{end+1} = path;
        end
        [v, found] = field(s, 'pattern');
        if found && ~isempty(v.value)
            if numel(bytes) > 4096
                error('praxo:schema', 'Pattern input exceeds limit');
            end
            [start, finish] = regexp(data.value, v.value, 'once');
            if isempty(start) || start ~= 1 || finish ~= numel(bytes)
                paths{end+1} = path;
            end
        end
    elseif any(strcmp(type, {'number', 'integer'}))
        [v, found] = field(s, 'minimum');
        if found && v.value ~= 0 && data.value < v.value
            paths{end+1} = path;
        end
        [v, found] = field(s, 'maximum');
        if found && v.value ~= 0 && data.value > v.value
            paths{end+1} = path;
        end
    end
end
end

function [value, found] = field(node, key)
value = [];
found = false;
for i = 1:size(node.value, 1)
    if strcmp(node.value{i, 1}, key)
        value = node.value{i, 2};
        found = true;
    end
end
end
