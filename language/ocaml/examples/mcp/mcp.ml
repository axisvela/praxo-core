#use "language/ocaml/praxo_core.ml"

let () =
  let transport method_name _params =
    match method_name with
    | "initialize" -> Object [("protocolVersion", String "2024-11-05");
                              ("serverInfo", Object [("name", String "example-mcp")])]
    | "tools/list" -> Object [("tools", Array [
        Object [("name", String "echo"); ("inputSchema", Object [("type", String "object")])];
        Object [("name", String "add"); ("inputSchema", Object [("type", String "object")])];
      ])]
    | "tools/call" -> Object [("structuredContent", Object [("sum", Number 5.0)])]
    | _ -> Object []
  in
  let client = mcp_client transport in
  let tools = mcp_list_tools client in
  let value = mcp_call_tool client "add" (Object []) in
  mcp_close client;
  if List.length tools <> 2 || value <> Object [("sum", Number 5.0)] then
    failwith "mcp example failed";
  print_endline "OCaml MCP example passed"
