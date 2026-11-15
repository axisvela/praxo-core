       >>source format free
identification division.
program-id. live-model-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "api.cpy".
copy "provider-options.cpy".
01 ws-env pic x(512).
01 ws-default-prompt pic x(200) value
    "What time is it? Use get_time with zone set to utc and reply with the time.".
01 ws-url-display pic x(512).
01 ws-model-display pic x(128).
procedure division.
    initialize px-options px-session px-prompt px-result
    initialize px-provider-options

    accept ws-env from environment "PRAXO_BASE_URL"
    if function trim(ws-env) = spaces
        move "http://localhost:11434/v1" to ws-env
    end-if
    move ws-env to px-provider-base-url
    compute px-provider-base-url-length = function length(
        function trim(px-provider-base-url trailing))
    move px-provider-base-url to ws-url-display

    accept ws-env from environment "PRAXO_MODEL"
    if function trim(ws-env) = spaces
        move "qwen3.5:4b" to ws-env
    end-if
    move ws-env to px-provider-model
    compute px-provider-model-length = function length(
        function trim(px-provider-model trailing))
    move px-provider-model to ws-model-display

    accept ws-env from environment "PRAXO_API_KEY"
    move ws-env to px-provider-api-key
    compute px-provider-api-key-length = function length(
        function trim(px-provider-api-key trailing))

    move "openai" to px-provider-kind
    move "live-transport" to px-provider-transport-program
    move '[{"type":"function","function":{"name":"get_time","description":"Return the current time in ISO 8601 format for the requested zone.","parameters":{"type":"object","properties":{"zone":{"type":"string","enum":["utc","local"],"description":"utc or local; defaults to utc"}}}}}]'
        to px-provider-tools
    compute px-provider-tools-length = function length(
        function trim(px-provider-tools trailing))
    move 0 to px-provider-max-tokens
    move px-provider-options to px-user-data

    accept px-prompt-text from environment "PRAXO_PROMPT"
    if function trim(px-prompt-text) = spaces
        move ws-default-prompt to px-prompt-text
    end-if
    compute px-prompt-length = function length(
        function trim(px-prompt-text trailing))

    move "praxo-openai" to px-model-program
    move "get-time-tool" to px-tool-program
    move "allow-get-time" to px-policy-program
    move 1 to px-allowed-tool-count
    move "get_time" to px-allowed-tools(1)
    move 4 to px-max-steps

    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error not = spaces
        display "live model run failed: " function trim(px-result-error)
        display "Check PRAXO_BASE_URL (" function trim(ws-url-display) ")"
        display "Check PRAXO_MODEL (" function trim(ws-model-display) ")"
        display "Check PRAXO_API_KEY and the caller-owned transport"
        stop run returning 1
    end-if
    display px-result-output(1:px-result-length)
    stop run.
end program live-model-example.

identification division.
program-id. get-time-tool recursive.
data division.
working-storage section.
01 ws-found pic 9(4).
01 ws-now pic x(21).
01 ws-formatted pic x(25).
linkage section.
copy "api.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    move 0 to ws-found
    inspect px-tool-input tallying ws-found
        for all '"zone":"local"'
    move function current-date to ws-now
    string ws-now(1:4) "-" ws-now(5:2) "-" ws-now(7:2) "T"
        ws-now(9:2) ":" ws-now(11:2) ":" ws-now(13:2)
        into ws-formatted
    if ws-found = 0
        string ws-formatted(1:19) "Z" into px-tool-output
    else
        move ws-formatted(1:19) to px-tool-output
    end-if
    compute px-tool-output-length = function length(
        function trim(px-tool-output trailing))
    goback.
end program get-time-tool.

identification division.
program-id. allow-get-time recursive.
data division.
linkage section.
copy "api.cpy".
procedure division using px-action px-user-data px-status.
    if px-action-kind = "model.generate"
        goback
    end-if
    if px-action-kind = "tool.invoke"
        and px-action-tool = "get_time"
        goback
    end-if
    move "AGENT_POLICY_DENIED" to px-status
    goback.
end program allow-get-time.

identification division.
program-id. live-transport recursive.
data division.
linkage section.
copy "provider-call.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-provider-call px-user-data px-status.
    move "PROVIDER_HTTP" to px-status
    goback.
end program live-transport.
