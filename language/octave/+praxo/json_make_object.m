function node = json_make_object(pairs)
node = struct('kind', 'object', 'value', {pairs});
end
