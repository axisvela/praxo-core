function [limit, code] = call_limit_tool(limit)
limit.tools = limit.tools + 1;
code = '';
if limit.toolLimit > 0 && limit.tools > limit.toolLimit
    code = 'AGENT_TOOL_CALL_LIMIT';
end
end
