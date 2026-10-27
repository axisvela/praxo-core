function [limit, code] = call_limit_model(limit)
limit.models = limit.models + 1;
code = '';
if limit.modelLimit > 0 && limit.models > limit.modelLimit
    code = 'AGENT_MODEL_CALL_LIMIT';
end
end
