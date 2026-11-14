push!(LOAD_PATH, "language/julia/src")
using PraxoCore

transport(method, params) = begin
    if method == "initialize"
        Dict("protocolVersion" => "2024-11-05", "serverInfo" => Dict("name" => "example-mcp"))
    elseif method == "tools/list"
        Dict("tools" => [
            Dict("name" => "echo", "description" => "Echo", "inputSchema" => Dict("type" => "object")),
            Dict("name" => "add", "description" => "Add", "inputSchema" => Dict("type" => "object")),
        ])
    elseif method == "tools/call"
        Dict("structuredContent" => Dict("sum" => 5))
    else
        Dict{String,Any}()
    end
end

client = mcp_client(transport)
tools = mcp_list_tools(client)
value = mcp_call_tool(client, "add", Dict{String,Any}())
mcp_close!(client)
@assert map(tool -> tool["name"], tools) == ["echo", "add"]
@assert value["sum"] == 5
println("Julia MCP example passed")
