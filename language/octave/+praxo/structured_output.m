function config = structured_output(schema, maxRepairs, repairer)
if nargin < 3, repairer = []; end
config = struct('schema', schema, 'maxRepairs', maxRepairs, 'repairer', repairer);
end
