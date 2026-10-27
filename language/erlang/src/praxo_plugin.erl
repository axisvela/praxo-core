-module(praxo_plugin).
-export([parse_manifest/1]).

-define(KNOWN_KINDS, [
    <<"tool.provider.v1">>,
    <<"model.provider.v1">>,
    <<"policy.provider.v1">>,
    <<"memory.provider.v1">>,
    <<"sandbox.provider.v1">>
]).

-define(MANIFEST_KEYS, [
    <<"schemaVersion">>,
    <<"id">>,
    <<"version">>,
    <<"kind">>,
    <<"entrypoint">>,
    <<"protocol">>,
    <<"capabilities">>,
    <<"permissions">>,
    <<"limits">>,
    <<"isolation">>,
    <<"health">>,
    <<"signature">>,
    <<"sbom">>
]).

-define(ENTRYPOINT_KEYS, [<<"type">>, <<"command">>, <<"module">>, <<"image">>, <<"args">>, <<"dir">>]).
-define(PERMISSION_KEYS, [<<"filesystem">>, <<"network">>, <<"env">>]).
-define(LIMIT_KEYS, [<<"memoryMB">>, <<"cpuMillis">>, <<"timeoutMs">>, <<"maxInflight">>]).
-define(HEALTH_KEYS, [<<"method">>, <<"intervalMs">>]).
-define(SIGNATURE_KEYS, [<<"algorithm">>, <<"keyId">>]).

parse_manifest(Raw) when is_binary(Raw) ->
    try
        {ok, do_parse(Raw)}
    catch
        throw:{plugin_error, _} -> {error, <<"PLUGIN_INVALID">>}
    end.

do_parse(Raw) ->
    case string:trim(Raw) of
        <<>> -> fail(<<"plugin: manifest is empty">>);
        _ -> ok
    end,
    Root =
        case praxo_json:parse(Raw) of
            {ok, Value} when is_map(Value) -> Value;
            _ -> fail(<<"plugin: manifest must be an object">>)
        end,
    check_keys(Root, ?MANIFEST_KEYS, <<"manifest">>),
    SchemaVersion = integer_field(praxo_json:get(Root, <<"schemaVersion">>), <<"schemaVersion">>),
    case SchemaVersion of
        1 -> ok;
        _ ->
            fail(
                <<"plugin: manifest: schemaVersion = ",
                    (integer_to_binary(SchemaVersion))/binary,
                    ", want 1">>
            )
    end,
    Id = string_field(praxo_json:get(Root, <<"id">>), <<"id">>),
    case valid_reverse_dns(Id) of
        true -> ok;
        false -> fail(<<"plugin: manifest: id ", Id/binary, " is not reverse-DNS">>)
    end,
    Version = string_field(praxo_json:get(Root, <<"version">>), <<"version">>),
    case valid_semver(Version) of
        true -> ok;
        false -> fail(<<"plugin: manifest: version ", Version/binary, " is not semver">>)
    end,
    Kind = string_field(praxo_json:get(Root, <<"kind">>), <<"kind">>),
    case lists:member(Kind, ?KNOWN_KINDS) of
        true -> ok;
        false -> fail(<<"plugin: manifest: kind ", Kind/binary, " is not a known contract">>)
    end,
    Protocol = string_field(praxo_json:get(Root, <<"protocol">>), <<"protocol">>),
    case Protocol of
        <<"jsonrpc-2">> -> ok;
        _ -> fail(<<"plugin: manifest: protocol = ", Protocol/binary, ", want jsonrpc-2">>)
    end,
    Entrypoint = object_field(praxo_json:get(Root, <<"entrypoint">>), <<"entrypoint">>),
    check_keys(Entrypoint, ?ENTRYPOINT_KEYS, <<"entrypoint">>),
    EntryType = string_field(praxo_json:get(Entrypoint, <<"type">>), <<"entrypoint.type">>),
    Required =
        case EntryType of
            <<"process">> -> <<"command">>;
            <<"wasm">> -> <<"module">>;
            <<"container">> -> <<"image">>;
            _ -> fail(<<"plugin: manifest: unknown entrypoint type ", EntryType/binary>>)
        end,
    case text_present(praxo_json:get(Entrypoint, Required)) of
        true -> ok;
        false ->
            fail(
                <<"plugin: manifest: ",
                    EntryType/binary,
                    " entrypoint requires ",
                    Required/binary>>
            )
    end,
    Isolation = string_field(praxo_json:get(Root, <<"isolation">>), <<"isolation">>),
    case Isolation of
        EntryType -> ok;
        _ ->
            fail(
                <<"plugin: manifest: isolation ",
                    Isolation/binary,
                    " does not match entrypoint ",
                    EntryType/binary>>
            )
    end,
    Permissions = object_field(praxo_json:get(Root, <<"permissions">>), <<"permissions">>),
    check_keys(Permissions, ?PERMISSION_KEYS, <<"permissions">>),
    Limits = object_field(praxo_json:get(Root, <<"limits">>), <<"limits">>),
    check_keys(Limits, ?LIMIT_KEYS, <<"limits">>),
    maps:foreach(
        fun(Key, Value) ->
            case integer_field(Value, <<"limits.", Key/binary>>) < 0 of
                true -> fail(<<"plugin: manifest: limits must not be negative">>);
                false -> ok
            end
        end,
        Limits
    ),
    Health = object_field(praxo_json:get(Root, <<"health">>), <<"health">>),
    check_keys(Health, ?HEALTH_KEYS, <<"health">>),
    check_signature(praxo_json:get(Root, <<"signature">>)),
    Capabilities = capabilities(praxo_json:get(Root, <<"capabilities">>)),
    #{
        schema_version => SchemaVersion,
        id => Id,
        version => Version,
        kind => Kind,
        entrypoint => Entrypoint,
        protocol => Protocol,
        capabilities => Capabilities,
        permissions => Permissions,
        limits => Limits,
        isolation => Isolation,
        health => Health
    }.

check_signature(undefined) -> ok;
check_signature(null) -> ok;
check_signature(Signature) ->
    SignatureMap = object_field(Signature, <<"signature">>),
    check_keys(SignatureMap, ?SIGNATURE_KEYS, <<"signature">>),
    case text_present(praxo_json:get(SignatureMap, <<"algorithm">>)) andalso
        text_present(praxo_json:get(SignatureMap, <<"keyId">>)) of
        true -> ok;
        false -> fail(<<"plugin: manifest: signature requires algorithm and keyId">>)
    end.

capabilities(undefined) -> [];
capabilities(null) -> [];
capabilities(Value) when is_list(Value) ->
    lists:foldl(
        fun(Item, Acc) ->
            Capability = string_field(Item, <<"capabilities">>),
            case Capability of
                <<>> -> fail(<<"plugin: manifest: capability must not be empty">>);
                _ ->
                    case lists:member(Capability, Acc) of
                        true -> fail(<<"plugin: manifest: duplicate capability">>);
                        false -> Acc ++ [Capability]
                    end
            end
        end,
        [],
        Value
    );
capabilities(_) ->
    fail(<<"plugin: manifest: capabilities must be an array">>).

fail(Message) ->
    throw({plugin_error, Message}).

check_keys(Value, Allowed, Where) when is_map(Value) ->
    maps:foreach(
        fun(Key, _) ->
            case lists:member(Key, Allowed) of
                true -> ok;
                false ->
                    fail(
                        <<"plugin: manifest: unknown field ",
                            Key/binary,
                            " in ",
                            Where/binary>>
                    )
            end
        end,
        Value
    ).

object_field(undefined, _) -> #{};
object_field(null, _) -> #{};
object_field(Value, _) when is_map(Value) -> Value;
object_field(_, Where) ->
    fail(<<"plugin: manifest: ", Where/binary, " must be an object">>).

string_field(Value, _) when is_binary(Value) -> Value;
string_field(_, Where) ->
    fail(<<"plugin: manifest: ", Where/binary, " must be a string">>).

integer_field(Value, _) when is_integer(Value) -> Value;
integer_field(Value, Where) when is_float(Value) ->
    case Value == trunc(Value) of
        true -> trunc(Value);
        false -> fail(<<"plugin: manifest: ", Where/binary, " must be an integer">>)
    end;
integer_field(_, Where) ->
    fail(<<"plugin: manifest: ", Where/binary, " must be an integer">>).

text_present(Value) -> is_binary(Value) andalso Value =/= <<>>.

valid_reverse_dns(Id) ->
    Parts = binary:split(Id, <<".">>, [global]),
    length(Parts) >= 2 andalso
        lists:all(
            fun(Part) ->
                Part =/= <<>> andalso
                    byte_size(Part) =< 63 andalso
                    lower_alnum(binary:first(Part)) andalso
                    lower_alnum(binary:last(Part)) andalso
                    re:run(Part, <<"^[a-z0-9-]+$">>, [{capture, none}]) == match
            end,
            Parts
        ).

lower_alnum(Character) ->
    (Character >= $a andalso Character =< $z) orelse
        (Character >= $0 andalso Character =< $9).

valid_semver(Version) ->
    Core0 = hd(binary:split(Version, <<"-">>)),
    Core = hd(binary:split(Core0, <<"+">>)),
    Parts = binary:split(Core, <<".">>, [global]),
    length(Parts) == 3 andalso
        lists:all(
            fun(Part) ->
                Part =/= <<>> andalso
                    not (byte_size(Part) > 1 andalso binary:first(Part) == $0) andalso
                    re:run(Part, <<"^[0-9]+$">>, [{capture, none}]) == match
            end,
            Parts
        ).
