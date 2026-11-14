#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    Transport = #{
        request => fun request/3,
        notify => fun(_Method, _Params) -> ok end,
        close => fun() -> ok end
    },
    {ok, Client0} = praxo_mcp:start(praxo_mcp:new(#{transport => Transport})),
    {ok, Tools} = praxo_mcp:list_tools(Client0),
    {ok, Result} = praxo_mcp:call_tool(Client0, <<"add">>, #{<<"a">> => 2, <<"b">> => 3}),
    ok = praxo_mcp:close(Client0),
    [<<"echo">>, <<"add">>] = [maps:get(<<"name">>, Tool) || Tool <- Tools],
    #{<<"sum">> := 5} = Result,
    io:format("Erlang MCP example passed~n").

request(<<"initialize">>, _Params, _Timeout) ->
    {ok, #{
        <<"protocolVersion">> => <<"2024-11-05">>,
        <<"capabilities">> => #{<<"tools">> => #{}},
        <<"serverInfo">> => #{<<"name">> => <<"example-mcp">>, <<"version">> => <<"1.0.0">>}
    }};
request(<<"tools/list">>, _Params, _Timeout) ->
    {ok, #{<<"tools">> => [
        #{<<"name">> => <<"echo">>, <<"description">> => <<"Echo input">>,
          <<"inputSchema">> => #{<<"type">> => <<"object">>}},
        #{<<"name">> => <<"add">>, <<"description">> => <<"Add two integers">>,
          <<"inputSchema">> => #{<<"type">> => <<"object">>}}
    ]}};
request(<<"tools/call">>, _Params, _Timeout) ->
    {ok, #{<<"structuredContent">> => #{<<"sum">> => 5}, <<"isError">> => false}};
request(_Method, _Params, _Timeout) ->
    {error, <<"MCP_RPC">>}.
