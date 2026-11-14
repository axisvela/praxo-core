schema = praxo.parse_json('{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}');
valid = praxo.parse_json('{"name":"ok"}');
invalid = praxo.parse_json('{}');
assert(isempty(praxo.validate_schema(schema, valid)));
assert(~isempty(praxo.validate_schema(schema, invalid)));
disp('MATLAB structured output example passed');
