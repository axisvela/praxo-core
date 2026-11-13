       >>source format free
identification division.
program-id. praxo-otel recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 ws-body pic x(16384).
01 ws-body-position binary-long.
01 ws-source pic x(4096).
01 ws-source-length binary-long.
01 ws-source-position binary-long.
01 ws-literal pic x(4096).
01 ws-piece pic x(16384).
01 ws-piece-length binary-long.
01 ws-attr-key pic x(128).
01 ws-attr-value pic x(2048).
01 ws-attr-value-length binary-long.
01 ws-attr-count binary-long.
01 ws-event-key pic x(8192).
01 ws-event-key-position binary-long.
01 ws-event-key-length binary-long.
01 ws-seed-key pic x(8192).
01 ws-seed-key-position binary-long.
01 ws-seed pic x(16).
01 ws-id-piece pic x(8).
01 ws-trace-id pic x(32).
01 ws-span-id pic x(16).
01 ws-hash pic 9(18) comp-5.
01 ws-hash-index binary-long.
01 ws-hex-index binary-long.
01 ws-hex-digit binary-long.
01 ws-hex-digits pic x(16) value "0123456789abcdef".
01 ws-nanos pic z(19).
01 ws-nanos-text pic x(19).
01 ws-loop binary-long.
01 ws-find binary-long.
01 ws-parent binary-long.
01 ws-key pic x(64).
01 ws-found binary-long.
01 ws-value-node binary-long.
01 ws-node binary-long.
01 ws-start binary-long.
01 ws-size binary-long.
01 ws-end binary-long.
01 ws-raw pic x(2048).
01 ws-raw-length binary-long.
local-storage section.
copy "otel-call.cpy".
copy "json.cpy".
linkage section.
copy "otel.cpy".
copy "otel-event.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-otel-options px-otel-result px-otel-event
    px-user-data px-status.
    initialize px-otel-result
    move spaces to px-status
    if function trim(px-otel-endpoint) = spaces
        move "OTEL_URL" to px-status
        goback
    end-if
    if px-otel-transport-program = spaces
        move "OTEL_HTTP" to px-status
        goback
    end-if
    if px-otel-allowed-key-count < 0
        or px-otel-allowed-key-count > 16
        move "OTEL_JSON" to px-status
        goback
    end-if
    move px-otel-event-nanos to ws-nanos
    move function trim(ws-nanos) to ws-nanos-text
    perform build-identifiers
    perform build-body
    if px-status not = spaces goback end-if
    move px-otel-endpoint to px-otel-url
    compute px-otel-url-length = function length(
        function trim(px-otel-endpoint))
    move "POST" to px-otel-method
    move "application/json" to px-otel-content-type
    move ws-body to px-otel-body
    compute px-otel-body-length = ws-body-position - 1
    move 0 to px-otel-status-code
    move spaces to px-otel-response
    move 0 to px-otel-response-length
    call px-otel-transport-program using px-otel-call px-user-data
        px-status
    if px-status not = spaces goback end-if
    if px-otel-status-code < 200 or px-otel-status-code >= 300
        move "OTEL_HTTP" to px-status
        compute px-otel-error-body-length = px-otel-response-length
        if px-otel-error-body-length > 512
            move 512 to px-otel-error-body-length
        end-if
        if px-otel-error-body-length > 0
            move px-otel-response(1:px-otel-error-body-length) to
                px-otel-error-body
        end-if
    end-if
    goback.
build-identifiers.
    move spaces to ws-event-key
    move 1 to ws-event-key-position
    string function trim(px-otel-event-session-id) delimited by size
        "|" delimited by size
        function trim(px-otel-event-run-id) delimited by size
        "|" delimited by size
        function trim(px-otel-event-type) delimited by size
        "|" delimited by size
        function trim(ws-nanos-text) delimited by size
        "|" delimited by size
        function trim(px-otel-event-data) delimited by size
        into ws-event-key
        with pointer ws-event-key-position
    end-string
    compute ws-event-key-length = ws-event-key-position - 1
    move "trace-a" to ws-seed
    perform stable-id
    move ws-id-piece to ws-trace-id(1:8)
    move "trace-b" to ws-seed
    perform stable-id
    move ws-id-piece to ws-trace-id(9:8)
    move "trace-c" to ws-seed
    perform stable-id
    move ws-id-piece to ws-trace-id(17:8)
    move "trace-d" to ws-seed
    perform stable-id
    move ws-id-piece to ws-trace-id(25:8)
    move "span-a" to ws-seed
    perform stable-id
    move ws-id-piece to ws-span-id(1:8)
    move "span-b" to ws-seed
    perform stable-id
    move ws-id-piece to ws-span-id(9:8).
stable-id.
    move spaces to ws-seed-key
    move 1 to ws-seed-key-position
    string ws-seed delimited by size
        ":" delimited by size
        ws-event-key(1:ws-event-key-length) delimited by size
        into ws-seed-key
        with pointer ws-seed-key-position
    end-string
    move 2166136261 to ws-hash
    perform varying ws-hash-index from 1 by 1
        until ws-hash-index >= ws-seed-key-position
        compute ws-hash = function mod(
            ws-hash * 16777619
            + function ord(ws-seed-key(ws-hash-index:1)),
            4294967296)
    end-perform
    move spaces to ws-id-piece
    perform varying ws-hex-index from 8 by -1
        until ws-hex-index < 1
        compute ws-hex-digit = function mod(ws-hash, 16) + 1
        move ws-hex-digits(ws-hex-digit:1) to
            ws-id-piece(ws-hex-index:1)
        compute ws-hash = function integer(ws-hash / 16)
    end-perform.
build-body.
    move 2 to ws-body-position
    move "{" to ws-body
    move '{"resourceSpans":[{"resource":{"attributes":[' to ws-literal
    perform append-literal
    move 0 to ws-attr-count
    move "service.name" to ws-attr-key
    if function trim(px-otel-service-name) = spaces
        move "praxo-core" to ws-attr-value
        move 10 to ws-attr-value-length
    else
        move function trim(px-otel-service-name) to ws-attr-value
        compute ws-attr-value-length = function length(
            function trim(px-otel-service-name))
    end-if
    perform append-attribute
    if px-status not = spaces exit paragraph end-if
    move ']},"scopeSpans":[{"scope":{"name":"praxo-core"},"spans":[{' to
        ws-literal
    perform append-literal
    move '"traceId":' to ws-literal
    perform append-literal
    move ws-trace-id to ws-source
    move 32 to ws-source-length
    perform quote-source
    if px-status not = spaces exit paragraph end-if
    move ',"spanId":' to ws-literal
    perform append-literal
    move ws-span-id to ws-source
    move 16 to ws-source-length
    perform quote-source
    if px-status not = spaces exit paragraph end-if
    move ',"name":' to ws-literal
    perform append-literal
    move spaces to ws-source
    move 1 to ws-source-position
    string "praxo." delimited by size
        function trim(px-otel-event-type) delimited by size
        into ws-source with pointer ws-source-position
    end-string
    compute ws-source-length = ws-source-position - 1
    perform quote-source
    if px-status not = spaces exit paragraph end-if
    move ',"kind":1,"startTimeUnixNano":' to ws-literal
    perform append-literal
    move function trim(ws-nanos-text) to ws-source
    compute ws-source-length = function length(
        function trim(ws-nanos-text))
    perform quote-source
    if px-status not = spaces exit paragraph end-if
    move ',"endTimeUnixNano":' to ws-literal
    perform append-literal
    move function trim(ws-nanos-text) to ws-source
    compute ws-source-length = function length(
        function trim(ws-nanos-text))
    perform quote-source
    if px-status not = spaces exit paragraph end-if
    move ',"attributes":[' to ws-literal
    perform append-literal
    move 0 to ws-attr-count
    move "praxo.event.type" to ws-attr-key
    move function trim(px-otel-event-type) to ws-attr-value
    compute ws-attr-value-length = function length(
        function trim(px-otel-event-type))
    perform append-attribute
    if px-status not = spaces exit paragraph end-if
    if function trim(px-otel-event-session-id) not = spaces
        move "praxo.session.id" to ws-attr-key
        move function trim(px-otel-event-session-id) to ws-attr-value
        compute ws-attr-value-length = function length(
            function trim(px-otel-event-session-id))
        perform append-attribute
        if px-status not = spaces exit paragraph end-if
    end-if
    if function trim(px-otel-event-run-id) not = spaces
        move "praxo.run.id" to ws-attr-key
        move function trim(px-otel-event-run-id) to ws-attr-value
        compute ws-attr-value-length = function length(
            function trim(px-otel-event-run-id))
        perform append-attribute
        if px-status not = spaces exit paragraph end-if
    end-if
    move "praxo.event.at" to ws-attr-key
    move function trim(ws-nanos-text) to ws-attr-value
    compute ws-attr-value-length = function length(
        function trim(ws-nanos-text))
    perform append-attribute
    if px-status not = spaces exit paragraph end-if
    if px-otel-event-data-length > 0
        perform append-data-attributes
        if px-status not = spaces exit paragraph end-if
    end-if
    move "]}]}]}]}" to ws-literal
    perform append-literal
    compute px-otel-output-length = ws-body-position - 1
    move ws-body to px-otel-output.
append-data-attributes.
    if px-otel-event-data-length > 2048
        move "OTEL_JSON" to px-status
        exit paragraph
    end-if
    move px-otel-event-data to px-json-text
    move px-otel-event-data-length to px-json-length
    move spaces to px-json-error
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces or px-json-count < 1
        or px-json-kind(1) not = 'O'
        move "OTEL_JSON" to px-status
        exit paragraph
    end-if
    move 1 to ws-parent
    perform varying ws-loop from 1 by 1
        until ws-loop > px-otel-allowed-key-count
        or px-status not = spaces
        move function trim(px-otel-allowed-keys(ws-loop)) to ws-key
        perform find-field
        if ws-found = 1
            move "praxo.event.data." to ws-attr-key
            move px-otel-allowed-keys(ws-loop) to ws-attr-key(18:64)
            if px-json-kind(ws-value-node) = 'S'
                move px-json-value(ws-value-node) to ws-attr-value
                move px-json-value-length(ws-value-node) to
                    ws-attr-value-length
            else
                move ws-value-node to ws-node
                perform raw-node
                move ws-raw to ws-attr-value
                move ws-raw-length to ws-attr-value-length
            end-if
            perform append-attribute
        end-if
    end-perform.
append-attribute.
    if ws-attr-count > 0
        move "," to ws-literal
        perform append-literal
    end-if
    move '{"key":' to ws-literal
    perform append-literal
    move ws-attr-key to ws-source
    compute ws-source-length = function length(
        function trim(ws-attr-key))
    perform quote-source
    if px-status not = spaces exit paragraph end-if
    move ',"value":{"stringValue":' to ws-literal
    perform append-literal
    move ws-attr-value to ws-source
    move ws-attr-value-length to ws-source-length
    perform quote-source
    if px-status not = spaces exit paragraph end-if
    move "}}" to ws-literal
    perform append-literal
    add 1 to ws-attr-count.
append-literal.
    compute ws-piece-length = function length(function trim(ws-literal))
    if ws-piece-length > 0
        move ws-literal(1:ws-piece-length) to ws-piece
        perform append-piece
    end-if.
append-piece.
    if ws-piece-length > 0
        if ws-body-position + ws-piece-length - 1 > 16384
            move "OTEL_JSON" to px-status
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
        move "OTEL_JSON" to px-status
        exit paragraph
    end-if
    move px-output-text to ws-piece
    move px-output-length to ws-piece-length
    perform append-piece.
find-field.
    move 0 to ws-found ws-value-node
    perform varying ws-find from 1 by 1 until ws-find > px-json-count
        if px-json-parent(ws-find) = ws-parent
            and px-json-kind(ws-find) = 'K'
            and function trim(px-json-value(ws-find)) = ws-key
            move 1 to ws-found
            compute ws-value-node = ws-find + 1
            exit perform
        end-if
    end-perform.
raw-node.
    move spaces to ws-raw
    move 0 to ws-raw-length
    if ws-node < 1 or ws-node > px-json-count goback end-if
    move px-json-start(ws-node) to ws-start
    move px-json-size(ws-node) to ws-size
    if ws-size < 1 or ws-start < 1 goback end-if
    compute ws-end = ws-start + ws-size - 1
    if ws-end > px-json-length goback end-if
    if ws-size > 2048
        move 2048 to ws-size
    end-if
    move px-json-text(ws-start:ws-size) to ws-raw
    move ws-size to ws-raw-length.
end program praxo-otel.
