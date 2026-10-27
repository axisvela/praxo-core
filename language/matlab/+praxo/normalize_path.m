function result = normalize_path(value)
path = strrep(value, '\', '/');
absolute = false;
prefix = '';
body = path;
if numel(path) >= 2 && path(2) == ':'
    body = path(3:end);
    absolute = ~isempty(body) && body(1) == '/';
    prefix = path(1:2);
    if absolute, prefix = [prefix '/']; end
elseif ~isempty(path) && path(1) == '/'
    prefix = '/';
    absolute = true;
end
parts = strsplit(body, '/');
stack = {};
for i = 1:numel(parts)
    part = parts{i};
    if isempty(part) || strcmp(part, '.')
        continue;
    elseif strcmp(part, '..')
        if isempty(stack)
            if ~absolute, stack{end + 1} = '..'; end
        elseif strcmp(stack{end}, '..')
            stack{end + 1} = '..';
        else
            stack(end) = [];
        end
    else
        stack{end + 1} = part;
    end
end
result = [prefix strjoin(stack, '/')];
if ispc, result = lower(result); end
end
