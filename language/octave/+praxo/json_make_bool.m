function node = json_make_bool(value)
node = struct('kind', 'boolean', 'value', logical(value));
end
