-module(praxo_retriever).
-export([document/1, document/2, func_retriever/1, retrieve/3]).

document(Options) when is_map(Options) ->
    #{
        id => maps:get(id, Options, <<>>),
        content => maps:get(content, Options, <<>>),
        metadata => maps:get(metadata, Options, undefined),
        score => maps:get(score, Options, undefined)
    };
document(Content) ->
    document(#{content => praxo_util:to_bin(Content)}).

document(Id, Content) ->
    document(#{
        id => praxo_util:to_bin(Id),
        content => praxo_util:to_bin(Content)
    }).

func_retriever(Fun) when is_function(Fun) ->
    Fun.

retrieve(_Retriever, _Query, Limit) when Limit < 0 ->
    {error, <<"RETRIEVER_INVALID">>};
retrieve(Retriever, Query, Limit) ->
    try Retriever(Query, Limit) of
        Documents when is_list(Documents) -> {ok, Documents};
        Other -> {ok, Other}
    catch
        throw:{praxo_error, Code, _} -> {error, Code};
        error:Reason -> {error, Reason}
    end.
