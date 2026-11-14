transport = %{
  request: fn method, _params, _timeout ->
    case method do
      "initialize" ->
        {:ok,
         %{
           "protocolVersion" => "2024-11-05",
           "capabilities" => %{"tools" => %{}},
           "serverInfo" => %{"name" => "example-mcp", "version" => "1.0.0"}
         }}

      "tools/list" ->
        {:ok,
         %{
           "tools" => [
             %{"name" => "echo", "description" => "Echo input", "inputSchema" => %{"type" => "object"}},
             %{"name" => "add", "description" => "Add two integers", "inputSchema" => %{"type" => "object"}}
           ]
         }}

      "tools/call" ->
        {:ok, %{"structuredContent" => %{"sum" => 5}, "isError" => false}}

      _ ->
        {:error, "MCP_RPC"}
    end
  end,
  notify: fn _method, _params -> :ok end,
  close: fn -> :ok end
}

{:ok, client} = Praxo.Mcp.connect(transport: transport)
{:ok, tools} = Praxo.Mcp.list_tools(client)
{:ok, result} = Praxo.Mcp.call_tool(client, "add", %{"a" => 2, "b" => 3})
:ok = Praxo.Mcp.close(client)

unless Enum.sort(Enum.map(tools, & &1.name)) == ["add", "echo"] do
  raise "unexpected tools"
end

unless result == %{"sum" => 5} do
  raise "unexpected result"
end

IO.puts("Elixir MCP example passed")
