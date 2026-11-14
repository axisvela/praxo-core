allow = praxo.checkpoint_new();
allow = praxo.checkpoint_register(allow, 'order');
value = praxo.parse_json('{"value":"x"}');
[data, code] = praxo.checkpoint_marshal(allow, 'order', value);
assert(isempty(code));
[decoded, code] = praxo.checkpoint_unmarshal(allow, data);
assert(isempty(code));
assert(praxo.json_equal(decoded, value));
disp('MATLAB checkpoint example passed');
