#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    BaseUrl = env("PRAXO_BASE_URL", <<"http://localhost:11434/v1">>),
    ModelName = env("PRAXO_MODEL", <<"qwen3.5:4b">>),
    ApiKey = env("PRAXO_API_KEY", <<>>),
    Prompt = env("PRAXO_PROMPT",
        <<"What time is it? Use get_time with zone set to utc and reply with the time.">>),
    AdapterOptions =
        case ApiKey of
            <<>> -> #{};
            _ -> #{api_key => ApiKey}
        end,
    Adapter = praxo_openai_compatible:new(BaseUrl, ModelName, AdapterOptions),
    Tool0 = praxo_agent:new_tool(
        <<"get_time">>,
        <<"Return the current time in ISO 8601 format for the requested zone.">>,
        fun(Arguments) -> current_time(maps:get(<<"zone">>, Arguments, <<"utc">>)) end
    ),
    Tool = Tool0#{parameters => #{
        <<"type">> => <<"object">>,
        <<"properties">> => #{
            <<"zone">> => #{
                <<"type">> => <<"string">>,
                <<"enum">> => [<<"utc">>, <<"local">>],
                <<"description">> => <<"utc or local; defaults to utc">>
            }
        }
    }},
    Options0 = praxo_agent:new_agent_options(
        praxo_openai_compatible:model(Adapter)),
    Options = Options0#{
        tools => [Tool],
        system_prompt =>
            <<"You are a concise assistant. Use the provided tools when they help.">>,
        max_steps => 4,
        allowed_tools => [<<"get_time">>],
        policy => fun(Action) ->
            case maps:get(kind, Action) of
                <<"model.generate">> ->
                    praxo_models:decision(true);
                <<"tool.invoke">> ->
                    praxo_models:decision(
                        maps:get(tool_name, Action) == <<"get_time">>,
                        <<"only get_time is permitted">>
                    );
                _ ->
                    praxo_models:decision(false, <<"unsupported action">>)
            end
        end
    },
    try praxo_agent:run_agent(
            Options, praxo_models:session(<<"live-model">>), Prompt) of
        {ok, Result, _} ->
            io:format("~s~n", [maps:get(output, Result)]);
        {error, Code, _} ->
            fail(Code, BaseUrl, ModelName)
    catch
        Class:Reason ->
            fail(io_lib:format("~p:~p", [Class, Reason]), BaseUrl, ModelName)
    end.

env(Name, Fallback) ->
    case os:getenv(Name) of
        false -> Fallback;
        "" -> Fallback;
        Value -> unicode:characters_to_binary(Value)
    end.

current_time(<<"local">>) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:local_time(),
    iolist_to_binary(io_lib:format(
        "~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B",
        [Year, Month, Day, Hour, Minute, Second]));
current_time(_) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:universal_time(),
    iolist_to_binary(io_lib:format(
        "~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
        [Year, Month, Day, Hour, Minute, Second])).

fail(Code, BaseUrl, ModelName) ->
    io:format(standard_error,
        "live model run failed: ~s~n~n"
        "Check PRAXO_BASE_URL (~s), PRAXO_MODEL (~s), and PRAXO_API_KEY.~n",
        [Code, BaseUrl, ModelName]),
    halt(1).
