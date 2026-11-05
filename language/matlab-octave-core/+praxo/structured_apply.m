function [output, code] = structured_apply(config, text)
[output, code] = apply_attempt(config, text, 0);
end

function [output, code] = apply_attempt(config, text, attempt)
value = praxo.extract_json(text);
if ~isempty(value) && isempty(praxo.validate_schema(config.schema, value))
    output = text;
    code = '';
    return;
end
output = '';
code = 'AGENT_STRUCTURED_OUTPUT';
if attempt >= config.maxRepairs || isempty(config.repairer)
    return;
end
try
    repaired = config.repairer(text);
catch
    return;
end
if ischar(repaired) && ~isempty(strtrim(repaired))
    [output, code] = apply_attempt(config, repaired, attempt + 1);
end
end
