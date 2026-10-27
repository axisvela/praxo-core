-module(praxo_sink).
-export([new/0, multi/1, filter/2, emit/2, kinds/1]).

new() ->
    #{mode => record, kinds => []}.

multi(Sinks) ->
    #{mode => multi, sinks => Sinks}.

filter(Target, Predicate) ->
    #{mode => filter, target => Target, predicate => Predicate}.

emit(#{mode := multi, sinks := Sinks} = Sink, Event) ->
    Sink#{sinks => [emit(Current, Event) || Current <- Sinks]};
emit(#{mode := filter, target := Target, predicate := Predicate} = Sink, Event) ->
    case Predicate == [] orelse lists:member(maps:get(kind, Event), Predicate) of
        true -> Sink#{target => emit(Target, Event)};
        false -> Sink
    end;
emit(Sink, Event) ->
    Sink#{kinds => maps:get(kinds, Sink) ++ [maps:get(kind, Event)]}.

kinds(#{mode := multi, sinks := Sinks}) ->
    [kinds(Sink) || Sink <- Sinks];
kinds(#{mode := filter, target := Target}) ->
    kinds(Target);
kinds(Sink) ->
    maps:get(kinds, Sink).
