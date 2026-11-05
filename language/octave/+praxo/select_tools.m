function selected = select_tools(selection, tools)
selected = {};
for i = 1:numel(tools)
    if any(strcmp(selection, tools{i}.name))
        selected{end + 1} = tools{i};
    end
end
end
