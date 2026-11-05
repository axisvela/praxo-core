function checker = path_checker(grants)
if isempty(grants)
    checker = struct('grants', {{}});
    return;
end
checker = struct('grants', {{}});
for i = 1:numel(grants)
    root = grants(i).root;
    access = grants(i).access;
    if isempty(root)
        error('praxo:policy', 'POLICY_ERROR');
    end
    if ~any(strcmp(access, {'read', 'write', 'readwrite'}))
        error('praxo:policy', 'POLICY_ERROR');
    end
    checker.grants{end + 1} = struct('root', praxo.normalize_path(root), 'access', access);
end
end
