function [valid, manifest] = validate_manifest(raw)
valid = false;
manifest = [];
try
    m = praxo.parse_json(raw);
    fields(m, {'schemaVersion','id','version','kind','entrypoint','protocol','capabilities','permissions','limits','isolation','health','signature','sbom'}, ...
        {'schemaVersion','id','version','kind','entrypoint','protocol','capabilities','permissions','limits','isolation','health'});
    require(integer(get(m, 'schemaVersion')) && get(m, 'schemaVersion').value == 1);
    require(matches(text(get(m, 'id')), '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?$'));
    require(matches(text(get(m, 'version')), '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'));
    require(any(strcmp(text(get(m, 'kind')), {'tool.provider.v1','model.provider.v1','policy.provider.v1','memory.provider.v1','sandbox.provider.v1'})));
    require(strcmp(text(get(m, 'protocol')), 'jsonrpc-2'));
    e = get(m, 'entrypoint');
    fields(e, {'type','command','module','image','args','dir'}, {'type'});
    typ = text(get(e, 'type'));
    require(any(strcmp(typ, {'process','wasm','container'})));
    require(strcmp(text(get(m, 'isolation')), typ));
    names = {'command','module','image','dir'};
    for i = 1:numel(names)
        if has(e, names{i}), text(get(e, names{i})); end
    end
    if strcmp(typ, 'process'), required = 'command';
    elseif strcmp(typ, 'wasm'), required = 'module';
    else, required = 'image'; end
    require(has(e, required) && ~isempty(text(get(e, required))));
    if has(e, 'args'), strings(get(e, 'args')); end
    caps = strings(get(m, 'capabilities'));
    require(all(~cellfun('isempty', caps)) && numel(unique(caps)) == numel(caps));
    p = get(m, 'permissions');
    fields(p, {'filesystem','network','env'}, {});
    if has(p, 'filesystem')
        a = array(get(p, 'filesystem'));
        for i = 1:numel(a)
            f = a{i};
            fields(f, {'path','mode'}, {'path','mode'});
            path = text(get(f, 'path'));
            require(~isempty(path) && no_parent(path));
            require(any(strcmp(text(get(f, 'mode')), {'read','write','readwrite'})));
        end
    end
    if has(p, 'network')
        a = array(get(p, 'network'));
        for i = 1:numel(a)
            n = a{i};
            fields(n, {'host','port'}, {'host','port'});
            require(~isempty(text(get(n, 'host'))));
            port = get(n, 'port');
            require(integer(port) && port.value >= 1 && port.value <= 65535);
        end
    end
    if has(p, 'env')
        a = strings(get(p, 'env'));
        for i = 1:numel(a)
            require(matches(a{i}, '^[A-Za-z_][A-Za-z0-9_]*$'));
        end
    end
    l = get(m, 'limits');
    names = {'memoryMB','cpuMillis','timeoutMs','maxInflight'};
    fields(l, names, {});
    for i = 1:numel(names)
        if has(l, names{i}), nonnegative(get(l, names{i})); end
    end
    h = get(m, 'health');
    fields(h, {'method','intervalMs'}, {});
    method = '';
    if has(h, 'method'), method = text(get(h, 'method')); end
    if has(h, 'intervalMs')
        interval = get(h, 'intervalMs');
        nonnegative(interval);
        require(interval.value == 0 || ~isempty(method));
    end
    if has(m, 'signature')
        sig = get(m, 'signature');
        fields(sig, {'algorithm','keyId'}, {'algorithm','keyId'});
        require(~isempty(text(get(sig, 'algorithm'))) && ~isempty(text(get(sig, 'keyId'))));
    end
    if has(m, 'sbom')
        path = text(get(m, 'sbom'));
        require(isempty(path) || (no_parent(path) && path(1) ~= '/' && path(1) ~= '\' && isempty(regexp(path, '^[A-Za-z]:', 'once'))));
    end
    valid = true;
    manifest = m;
catch
    valid = false;
    manifest = [];
end
end

function require(condition)
if ~condition, error('praxo:manifest', 'Invalid manifest'); end
end

function fields(node, allowed, required)
require(strcmp(node.kind, 'object'));
keys = node.value(:, 1);
require(numel(unique(keys)) == numel(keys) && all(ismember(keys, allowed)) && all(ismember(required, keys)));
end

function result = has(node, name)
result = any(strcmp(node.value(:, 1), name));
end

function value = get(node, name)
index = find(strcmp(node.value(:, 1), name), 1);
require(~isempty(index));
value = node.value{index, 2};
end

function value = text(node)
require(strcmp(node.kind, 'string'));
value = node.value;
end

function value = array(node)
require(strcmp(node.kind, 'array'));
value = node.value;
end

function value = strings(node)
a = array(node);
value = cell(size(a));
for i = 1:numel(a), value{i} = text(a{i}); end
end

function result = integer(node)
result = strcmp(node.kind, 'number') && isfinite(node.value) && fix(node.value) == node.value && abs(node.value) <= 9007199254740991;
end

function nonnegative(node)
require(integer(node) && node.value >= 0);
end

function result = matches(value, pattern)
[start, finish] = regexp(value, pattern, 'once');
result = ~isempty(start) && start == 1 && finish == numel(value);
end

function result = no_parent(path)
parts = regexp(strrep(path, '\', '/'), '/', 'split');
result = ~any(strcmp(parts, '..'));
end
