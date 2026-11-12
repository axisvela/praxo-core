module Mcp

export McpClient, mcp_client, mcp_list_tools, mcp_call_tool, mcp_close!

struct McpClient
    transport::Function
    client_version::String
    protocol_version::String
    server_info::Dict{String,Any}
    closed::Bool
end

function mcp_client(transport; client_version = "0.3.0",
                    protocol_version = "2024-11-05")
    result = transport("initialize", Dict(
        "protocolVersion" => protocol_version,
        "capabilities" => Dict{String,Any}(),
        "clientInfo" => Dict("name" => "praxo-core",
                             "version" => client_version),
    ))
    version = get(result, "protocolVersion", "")
    version isa String && !isempty(version) ||
        error("mcp: initialize returned no protocol version")
    info = get(result, "serverInfo", Dict{String,Any}())
    McpClient(transport, client_version, version,
              info isa Dict ? Dict{String,Any}(info) : Dict{String,Any}(),
              false)
end

function mcp_list_tools(client::McpClient)
    tools = Dict{String,Any}[]
    names = Set{String}()
    cursors = Set{String}()
    cursor = ""
    while true
        params = Dict{String,Any}()
        isempty(cursor) || (params["cursor"] = cursor)
        result = client.transport("tools/list", params)
        raw = get(result, "tools", Any[])
        raw isa AbstractVector || error("mcp: tools/list tools must be an array")
        for item in raw
            item isa Dict || error("mcp: tool definition must be an object")
            name = get(item, "name", "")
            name isa String && !isempty(name) ||
                error("mcp: tool name is required")
            name in names &&
                error("mcp: duplicate tool " * name)
            push!(names, name)
            push!(tools, Dict{String,Any}(item))
        end
        cursor = get(result, "nextCursor", "")
        cursor isa String || error("mcp: nextCursor must be a string")
        isempty(cursor) && break
        cursor in cursors &&
            error("mcp: repeated tool pagination cursor")
        push!(cursors, cursor)
    end
    tools
end

function mcp_call_tool(client::McpClient, name::String,
                       arguments::Dict = Dict{String,Any}())
    result = client.transport("tools/call", Dict(
        "name" => name,
        "arguments" => arguments,
    ))
    get(result, "isError", false) === true &&
        error("mcp: tool " * name * " failed")
    haskey(result, "structuredContent") &&
        return result["structuredContent"]
    texts = String[]
    for item in get(result, "content", Any[])
        item isa Dict && get(item, "type", "") == "text" &&
            push!(texts, string(get(item, "text", "")))
    end
    isempty(texts) && return nothing
    length(texts) == 1 && return texts[1]
    texts
end

mcp_close!(client::McpClient) = (client.closed = true; nothing)

end
