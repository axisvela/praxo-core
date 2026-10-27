function code = check_tool_selected(selection, name)
if any(strcmp(selection, name))
    code = '';
else
    code = 'AGENT_TOOL_NOT_SELECTED';
end
end
