function value = path_grant(root, access)
if nargin < 2, access = 'read'; end
value = struct('root', root, 'access', access);
end
