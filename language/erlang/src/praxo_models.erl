-module(praxo_models).
-export([
    sdk_version/0,
    spec_version/0,
    roles/0,
    stream_kinds/0,
    content_block/2,
    tool_call/2,
    tool_call/3,
    message/2,
    message_assistant/1,
    message_assistant/2,
    message_tool/2,
    tool_spec/2,
    usage/0,
    usage/2,
    add_usage/2,
    request/1,
    request/2,
    response/1,
    response/2,
    session/1,
    session/2,
    run_result/4,
    memory_record/3,
    memory_record/4,
    path_grant/1,
    path_grant/2,
    decision/1,
    decision/2,
    action/2,
    action/3,
    action/4,
    context_budget/2,
    event/2,
    event/3,
    event/4,
    message_wire/1
]).

sdk_version() -> <<"0.1.0">>.

spec_version() -> <<"0.2.0">>.

roles() ->
    #{
        system => <<"system">>,
        user => <<"user">>,
        assistant => <<"assistant">>,
        tool => <<"tool">>
    }.

stream_kinds() ->
    [<<"values">>, <<"updates">>, <<"messages">>, <<"tasks">>, <<"debug">>, <<"checkpoint">>].

content_block(Kind, Text) ->
    #{kind => praxo_util:to_bin(Kind), text => Text, image_url => undefined, data => undefined}.

tool_call(Name, Arguments) ->
    tool_call(<<>>, Name, Arguments).

tool_call(Id, Name, Arguments) ->
    #{id => praxo_util:to_bin(Id), name => praxo_util:to_bin(Name), arguments => Arguments}.

message(Role, Content) ->
    #{
        role => praxo_util:to_bin(Role),
        content => Content,
        content_blocks => [],
        tool_calls => [],
        tool_id => undefined
    }.

message_assistant(Content) ->
    message_assistant(Content, []).

message_assistant(Content, ToolCalls) ->
    (message(assistant, Content))#{tool_calls => ToolCalls}.

message_tool(Content, ToolId) ->
    (message(tool, Content))#{tool_id => ToolId}.

tool_spec(Name, Description) ->
    #{name => praxo_util:to_bin(Name), description => praxo_util:to_bin(Description)}.

usage() -> usage(0, 0).

usage(InputTokens, OutputTokens) ->
    #{input_tokens => InputTokens, output_tokens => OutputTokens}.

add_usage(Left, Right) ->
    #{
        input_tokens => maps:get(input_tokens, Left) + maps:get(input_tokens, Right),
        output_tokens => maps:get(output_tokens, Left) + maps:get(output_tokens, Right)
    }.

request(Messages) -> request(Messages, []).

request(Messages, Tools) ->
    #{messages => Messages, tools => Tools, tool_choice => undefined}.

response(Message) -> response(Message, usage()).

response(Message, Usage) ->
    #{message => Message, usage => Usage}.

session(Id) -> session(Id, []).

session(Id, Messages) ->
    #{id => praxo_util:to_bin(Id), messages => Messages}.

run_result(RunId, Output, Steps, Usage) ->
    #{
        run_id => RunId,
        output => Output,
        steps => Steps,
        usage => Usage
    }.

memory_record(Id, Frame, Content) ->
    memory_record(Id, Frame, Content, undefined).

memory_record(Id, Frame, Content, CreatedAt) ->
    #{
        id => praxo_util:to_bin(Id),
        frame => praxo_util:to_bin(Frame),
        content => Content,
        created_at => CreatedAt
    }.

path_grant(Root) -> path_grant(Root, <<"read">>).

path_grant(Root, Access) ->
    #{root => praxo_util:to_bin(Root), access => praxo_util:to_bin(Access)}.

decision(Allowed) -> decision(Allowed, <<>>).

decision(Allowed, Reason) ->
    #{allowed => Allowed, reason => praxo_util:to_bin(Reason)}.

action(Kind, SessionId) -> action(Kind, SessionId, undefined, #{}).

action(Kind, SessionId, ToolName) -> action(Kind, SessionId, ToolName, #{}).

action(Kind, SessionId, ToolName, Arguments) ->
    #{
        kind => praxo_util:to_bin(Kind),
        session_id => praxo_util:to_bin(SessionId),
        tool_name => ToolName,
        arguments => Arguments
    }.

context_budget(MaxTokens, KeepRecent) ->
    #{max_tokens => MaxTokens, keep_recent => KeepRecent}.

event(Kind, SessionId) -> event(Kind, SessionId, undefined, null).

event(Kind, SessionId, RunId) -> event(Kind, SessionId, RunId, null).

event(Kind, SessionId, RunId, Data) ->
    #{
        kind => praxo_util:to_bin(Kind),
        session_id => praxo_util:to_bin(SessionId),
        run_id => RunId,
        data => Data
    }.

message_wire(Message) ->
    Base0 = #{<<"role">> => maps:get(role, Message)},
    Content = maps:get(content, Message),
    ContentBlocks = maps:get(content_blocks, Message),
    ToolCalls = maps:get(tool_calls, Message),
    ToolId = maps:get(tool_id, Message),
    Base1 =
        case Content =/= <<>> orelse
            (ContentBlocks == [] andalso ToolCalls == [] andalso ToolId == undefined) of
            true -> Base0#{<<"content">> => Content};
            false -> Base0
        end,
    Base2 =
        case ContentBlocks of
            [] -> Base1;
            _ ->
                Blocks = [
                    maybe_put(
                        maybe_put(
                            maybe_put(#{<<"type">> => maps:get(kind, Block)}, <<"text">>, maps:get(text, Block)),
                            <<"image_url">>,
                            maps:get(image_url, Block)
                        ),
                        <<"data">>,
                        maps:get(data, Block)
                    )
                 || Block <- ContentBlocks
                ],
                Base1#{<<"contentBlocks">> => Blocks}
        end,
    Base3 =
        case ToolCalls of
            [] -> Base2;
            _ ->
                Calls = [
                    #{
                        <<"id">> => maps:get(id, Call),
                        <<"name">> => maps:get(name, Call),
                        <<"arguments">> => maps:get(arguments, Call)
                    }
                 || Call <- ToolCalls
                ],
                Base2#{<<"toolCalls">> => Calls}
        end,
    case ToolId of
        undefined -> Base3;
        _ -> Base3#{<<"toolId">> => ToolId}
    end.

maybe_put(Map, _Key, undefined) -> Map;
maybe_put(Map, _Key, <<>>) -> Map;
maybe_put(Map, Key, Value) -> Map#{Key => Value}.
