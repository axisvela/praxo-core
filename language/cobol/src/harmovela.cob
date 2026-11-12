       >>source format free
identification division.
program-id. praxo-harmovela recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 ws-body pic x(16384).
01 ws-body-position binary-long.
01 ws-source pic x(4096).
01 ws-source-length binary-long.
01 ws-literal pic x(4096).
01 ws-piece pic x(16384).
01 ws-piece-length binary-long.
01 ws-url pic x(1024).
01 ws-url-length binary-long.
01 ws-id pic x(256).
01 ws-id-length binary-long.
01 ws-prefix pic x(128).
01 ws-prefix-length binary-long.
01 ws-suffix pic x(64).
01 ws-suffix-length binary-long.
local-storage section.
copy "harmovela-call.cpy".
copy "json.cpy".
linkage section.
copy "harmovela.cpy".
01 px-harmovela-event.
   05 px-harmovela-event-kind pic x(32).
   05 px-harmovela-event-tool pic x(64).
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-harmovela-options px-harmovela-result
    px-harmovela-event px-user-data px-status.
    initialize px-harmovela-result
    move spaces to px-status
    if px-harmovela-base-url = spaces
        move "HARMOVELA_BASE_URL" to px-status
        goback
    end-if
    move 2 to ws-body-position
    move "{" to ws-body
    move '"spec_version":' to ws-literal
    perform append-literal
    if px-harmovela-spec = spaces
        move "0.2" to ws-source
        move 3 to ws-source-length
    else
        move function trim(px-harmovela-spec) to ws-source
        compute ws-source-length = function length(
            function trim(px-harmovela-spec))
    end-if
    perform quote-source
    move ',"id":' to ws-literal
    perform append-literal
    if px-harmovela-id-prefix = spaces
        move "event" to ws-prefix
        move 5 to ws-prefix-length
    else
        move function trim(px-harmovela-id-prefix) to ws-prefix
        compute ws-prefix-length = function length(
            function trim(px-harmovela-id-prefix))
    end-if
    if px-harmovela-id-suffix = spaces
        move "0" to ws-suffix
        move 1 to ws-suffix-length
    else
        move function trim(px-harmovela-id-suffix) to ws-suffix
        compute ws-suffix-length = function length(
            function trim(px-harmovela-id-suffix))
    end-if
    move ws-prefix(1:ws-prefix-length) to ws-id
    add 1 to ws-prefix-length
    move "-" to ws-id(ws-prefix-length:1)
    add 1 to ws-prefix-length
    move ws-suffix(1:ws-suffix-length) to
        ws-id(ws-prefix-length:ws-suffix-length)
    compute ws-id-length = ws-prefix-length + ws-suffix-length - 1
    move ws-id to ws-source
    move ws-id-length to ws-source-length
    perform quote-source
    move ',"type":' to ws-literal
    perform append-literal
    move px-harmovela-event-kind to ws-source
    compute ws-source-length = function length(
        function trim(px-harmovela-event-kind))
    perform quote-source
    move ',"source":' to ws-literal
    perform append-literal
    if px-harmovela-source = spaces
        move "praxo-core" to ws-source
        move 10 to ws-source-length
    else
        move function trim(px-harmovela-source) to ws-source
        compute ws-source-length = function length(
            function trim(px-harmovela-source))
    end-if
    perform quote-source
    move ',"created_at":' to ws-literal
    perform append-literal
    move px-harmovela-created-at to ws-source
    compute ws-source-length = function length(
        function trim(px-harmovela-created-at))
    perform quote-source
    move ',"payload":' to ws-literal
    perform append-literal
    if px-harmovela-event-tool = spaces
        move "{}" to ws-literal
        perform append-literal
    else
        move '{"name":' to ws-literal
        perform append-literal
        move function trim(px-harmovela-event-tool) to ws-source
        compute ws-source-length = function length(
            function trim(px-harmovela-event-tool))
        perform quote-source
        move "}" to ws-literal
        perform append-literal
    end-if
    move "}" to ws-literal
    perform append-literal
    compute px-harmovela-output-length = ws-body-position - 1
    move ws-body to px-harmovela-output

    move px-harmovela-base-url to ws-url
    compute ws-url-length = function length(
        function trim(px-harmovela-base-url))
    perform until ws-url-length = 0
        if ws-url(ws-url-length:1) not = "/" exit perform end-if
        subtract 1 from ws-url-length
    end-perform
    compute ws-piece-length = ws-url-length + 1
    move "/events" to ws-url(ws-piece-length:7)
    add 7 to ws-url-length
    move ws-url to px-harmovela-url
    move ws-url-length to px-harmovela-url-length
    move "POST" to px-harmovela-method
    move "application/json" to px-harmovela-content-type
    move ws-body to px-harmovela-body
    move px-harmovela-output-length to px-harmovela-body-length
    move 0 to px-harmovela-status-code
    move spaces to px-harmovela-response
    move 0 to px-harmovela-response-length
    call px-harmovela-transport-program using px-harmovela-call
        px-user-data px-status
    if px-status not = spaces goback end-if
    if px-harmovela-status-code < 200
        or px-harmovela-status-code >= 300
        move "HARMOVELA_HTTP" to px-status
    end-if
    goback.
append-literal.
    compute ws-piece-length = function length(function trim(ws-literal))
    if ws-piece-length > 0
        move ws-literal(1:ws-piece-length) to ws-piece
        perform append-piece
    end-if.
append-piece.
    if ws-piece-length > 0
        if ws-body-position + ws-piece-length - 1 > 16384
            move "HARMOVELA_JSON" to px-status
            exit paragraph
        end-if
        move ws-piece(1:ws-piece-length) to
            ws-body(ws-body-position:ws-piece-length)
        add ws-piece-length to ws-body-position
    end-if.
quote-source.
    move ws-source to px-string-value
    move ws-source-length to px-string-length
    move spaces to px-json-error
    call "praxo-json-quote" using px-json-string px-json-output
        px-json-error
    if px-json-error not = spaces
        move "HARMOVELA_JSON" to px-status
        exit paragraph
    end-if
    move px-output-text to ws-piece
    move px-output-length to ws-piece-length
    perform append-piece.
end program praxo-harmovela.
