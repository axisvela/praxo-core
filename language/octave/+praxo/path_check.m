function decision = path_check(checker, target, need)
if ~any(strcmp(need, {'read', 'write', 'readwrite'}))
    error('praxo:policy', 'POLICY_ERROR');
end
if isempty(checker.grants)
    decision = struct('allowed', false, 'reason', 'no allowed roots');
    return;
end
resolved = praxo.normalize_path(target);
for i = 1:numel(checker.grants)
    grant = checker.grants{i};
    if path_within(grant.root, resolved) && access_allows(grant.access, need)
        decision = struct('allowed', true, 'reason', 'allowed');
        return;
    end
end
for i = 1:numel(checker.grants)
    if path_within(checker.grants{i}.root, resolved)
        decision = struct('allowed', false, 'reason', 'insufficient grant');
        return;
    end
end
decision = struct('allowed', false, 'reason', 'outside roots');
end

function result = path_within(root, target)
result = strcmp(root, target) || (numel(target) > numel(root) && strncmp(target, [root '/'], numel(root) + 1));
end

function result = access_allows(granted, need)
switch granted
    case 'readwrite'
        result = true;
    case 'read'
        result = strcmp(need, 'read');
    case 'write'
        result = strcmp(need, 'write');
    otherwise
        result = false;
end
end
