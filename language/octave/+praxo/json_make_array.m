function node = json_make_array(items)
node = struct('kind', 'array', 'value', {items});
end
