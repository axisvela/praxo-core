function test_middleware()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
document = praxo.parse_json(fileread(fullfile(root, 'spec', 'vectors', 'middleware.json')));
vectors = praxo.json_field(document, 'vectors');
for i = 1:numel(vectors.value)
    input = praxo.json_field(vectors.value{i}, 'input');
    expect = praxo.json_field(vectors.value{i}, 'expect');
    operation = field_value(input, 'operation', '');
    switch operation
        case 'pii'
            text = field_value(input, 'text', '');
            assert(strcmp(praxo.pii_redact(text), field_value(expect, 'text', '')));
        case 'pii-value'
            value = node_or(input, 'value', praxo.json_make_null());
            assert(praxo.json_equal(praxo.redact_value(value), node_or(expect, 'value', praxo.json_make_null())));
        case 'structured'
            schema = node_or(input, 'schema', praxo.json_make_object({}));
            repairs = praxo.json_int(input, 'maxRepairs', 0);
            [repair_node, found] = praxo.json_field(input, 'repairOutput');
            repairer = [];
            if found
                repair_text = repair_node.value;
                repairer = @(text) repair_text;
            end
            config = praxo.structured_output(schema, repairs, repairer);
            [output, code] = praxo.structured_apply(config, field_value(input, 'output', ''));
            expected_ok = field_value(expect, 'ok', false);
            assert(isempty(code) == expected_ok);
            if expected_ok
                assert(strcmp(output, field_value(expect, 'output', '')));
            else
                assert(strcmp(code, field_value(expect, 'errorCode', '')));
            end
        case 'call-limit'
            limit = praxo.call_limit(praxo.json_int(input, 'modelLimit', 0), ...
                praxo.json_int(input, 'toolLimit', 0));
            calls = praxo.json_field(input, 'calls');
            outcomes = cell(1, numel(calls.value));
            for j = 1:numel(calls.value)
                if strcmp(calls.value{j}.value, 'model')
                    [limit, code] = praxo.call_limit_model(limit);
                else
                    [limit, code] = praxo.call_limit_tool(limit);
                end
                if isempty(code), outcomes{j} = 'ok'; else, outcomes{j} = code; end
            end
            expected = node_or(expect, 'outcomes', praxo.json_make_null());
            assert(praxo.json_equal(strings_node(outcomes), expected));
        case 'tool-selection'
            selected = list_values(input, 'selected');
            selection = praxo.tool_selection(selected);
            tools = {};
            raw_tools = praxo.json_field(input, 'tools');
            for j = 1:numel(raw_tools.value)
                tools{j} = struct('name', raw_tools.value{j}.value, 'description', '');
            end
            advertised = praxo.select_tools(selection, tools);
            names = cell(1, numel(advertised));
            for j = 1:numel(advertised), names{j} = advertised{j}.name; end
            assert(praxo.json_equal(strings_node(names), node_or(expect, 'advertised', praxo.json_make_null())));
            code = praxo.check_tool_selected(selection, field_value(input, 'requested', ''));
            if isempty(code), reject = 'ok'; else, reject = code; end
            assert(strcmp(reject, field_value(expect, 'reject', '')));
        case 'fallback'
            content = field_value(input, 'fallbackContent', '');
            model = praxo.fallback_model(failing_model(), static_model(content));
            response = model(struct('messages', {{}}, 'tools', {{}}));
            assert(strcmp(response.content, content));
    end
end
disp('test_middleware passed');
end

function values = list_values(node, key)
raw = praxo.json_field(node, key);
values = cell(1, numel(raw.value));
for i = 1:numel(raw.value), values{i} = raw.value{i}.value; end
end

function node = strings_node(values)
items = cell(1, numel(values));
for i = 1:numel(values), items{i} = praxo.json_make_string(values{i}); end
node = praxo.json_make_array(items);
end

function value = node_or(node, key, fallback)
[value, found] = praxo.json_field(node, key);
if ~found, value = fallback; end
end

function value = field_value(node, key, fallback)
[item, found] = praxo.json_field(node, key);
if found, value = item.value; else, value = fallback; end
end

function model = static_model(content)
model = @(request) struct('content', content);
end

function model = failing_model()
model = @(request) error('test:failing', 'model failed');
end
