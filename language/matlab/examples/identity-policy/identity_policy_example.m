function identity_policy_example()
    operator = struct('tenant', 'acme', 'role', 'operator', 'active', true);
    assert(authorize(operator, 'record', 'acme'));
    viewer = operator;
    viewer.role = 'viewer';
    assert(~authorize(viewer, 'record', 'acme'));
    assert(~authorize(operator, 'record', 'other'));
    inactive = operator;
    inactive.active = false;
    assert(~authorize(inactive, 'record', 'acme'));
    disp('MATLAB identity policy example passed');
end

function allowed = authorize(principal, tool, tenant)
    allowed = principal.active && strcmp(principal.role, 'operator') && ...
        strcmp(principal.tenant, tenant) && strcmp(tool, 'record');
end
