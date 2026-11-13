       >>source format free
identification division.
program-id. praxo-openai recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "provider-options.cpy".
01 ws-body pic x(16384).
01 ws-body-position binary-long.
01 ws-source pic x(4096).
01 ws-source-length binary-long.
01 ws-literal pic x(4096).
01 ws-piece pic x(16384).
01 ws-piece-length binary-long.
01 ws-url pic x(1024).
01 ws-url-length binary-long.
01 ws-index binary-long.
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
01 ws-raw pic x(8192).
01 ws-raw-length binary-long.
01 ws-choice binary-long.
01 ws-message binary-long.
01 ws-tools-node binary-long.
01 ws-number pic 9(9).
01 ws-max-length binary-long.
local-storage section.
copy "provider-call.cpy".
copy "json.cpy".
linkage section.
01 px-session.
   05 px-message-count binary-long.
   05 px-messages occurs 64 times.
      10 px-role pic x(12).
      10 px-content pic x(2048).
      10 px-content-length binary-long.
      10 px-message-call-id pic x(64).
01 px-response.
   05 px-answer pic x(2048).
   05 px-answer-length binary-long.
   05 px-input-tokens pic s9(15) comp-3.
   05 px-output-tokens pic s9(15) comp-3.
   05 px-call-count binary-long.
   05 px-calls occurs 8 times.
      10 px-call-id pic x(64).
      10 px-call-name pic x(64).
      10 px-call-input pic x(2048).
      10 px-call-input-length binary-long.
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-session px-response px-user-data px-status.
    initialize px-response
    move spaces to px-status
    move px-user-data to px-provider-options
    if px-provider-base-url = spaces
        or px-provider-model = spaces
        move "PROVIDER_HTTP" to px-status
        goback
    end-if
    if px-provider-transport-program = spaces
        move "PROVIDER_HTTP" to px-status
        goback
    end-if
    move 2 to ws-body-position
    move "{" to ws-body
    move '"model":' to ws-literal
    perform append-literal
    move function trim(px-provider-model) to ws-source
    compute ws-source-length = function length(
        function trim(px-provider-model))
    perform quote-source
    move ',"messages":[' to ws-literal
    perform append-literal
    if px-message-count < 0 or px-message-count > 64
        move "PROVIDER_JSON" to px-status
        goback
    end-if
    perform varying ws-loop from 1 by 1
        until ws-loop > px-message-count or px-status not = spaces
        if ws-loop > 1
            move "," to ws-literal
            perform append-literal
        end-if
        move '{"role":' to ws-literal
        perform append-literal
        move function trim(px-role(ws-loop)) to ws-source
        compute ws-source-length = function length(
            function trim(px-role(ws-loop)))
        perform quote-source
        move ',"content":' to ws-literal
        perform append-literal
        move px-content(ws-loop) to ws-source
        move px-content-length(ws-loop) to ws-source-length
        perform quote-source
        if function trim(px-message-call-id(ws-loop)) not = spaces
            move ',"tool_call_id":' to ws-literal
            perform append-literal
            move function trim(px-message-call-id(ws-loop)) to ws-source
            compute ws-source-length = function length(
                function trim(px-message-call-id(ws-loop)))
            perform quote-source
        end-if
        move "}" to ws-literal
        perform append-literal
    end-perform
    if px-status not = spaces goback end-if
    move "]" to ws-literal
    perform append-literal
    if px-provider-tools-length > 0
        move ',"tools":' to ws-literal
        perform append-literal
        move px-provider-tools-length to ws-piece-length
        move px-provider-tools to ws-piece
        perform append-piece
    end-if
    if px-provider-max-tokens > 0
        move ',"max_tokens":' to ws-literal
        perform append-literal
        move px-provider-max-tokens to ws-number
        move function trim(ws-number) to ws-source
        compute ws-source-length = function length(
            function trim(ws-number))
        move ws-source(1:ws-source-length) to ws-piece
        move ws-source-length to ws-piece-length
        perform append-piece
    end-if
    move "}" to ws-literal
    perform append-literal
    if px-status not = spaces goback end-if

    move function trim(px-provider-base-url) to ws-url
    compute ws-url-length = function length(
        function trim(px-provider-base-url))
    perform until ws-url-length = 0
        if ws-url(ws-url-length:1) not = "/" exit perform end-if
        subtract 1 from ws-url-length
    end-perform
    compute ws-piece-length = ws-url-length + 1
    move "/chat/completions" to ws-url(ws-piece-length:17)
    add 17 to ws-url-length
    move ws-url to px-provider-url
    move ws-url-length to px-provider-url-length
    move ws-body to px-provider-payload
    compute px-provider-payload-length = ws-body-position - 1
    move px-provider-api-key to px-provider-api-key-send
    move px-provider-api-key-length to px-provider-api-key-send-length
    move 0 to px-provider-status-code
    move spaces to px-provider-response
    move 0 to px-provider-response-length
    call px-provider-transport-program using px-provider-call
        px-user-data px-status
    if px-status not = spaces goback end-if
    if px-provider-status-code < 200
        or px-provider-status-code >= 300
        move "PROVIDER_HTTP" to px-status
        goback
    end-if
    move px-provider-response to px-json-text
    move px-provider-response-length to px-json-length
    move spaces to px-json-error
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces or px-json-count < 1
        or px-json-kind(1) not = 'O'
        move "PROVIDER_JSON" to px-status
        goback
    end-if
    move 1 to ws-parent
    move "choices" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = 'A'
        move "PROVIDER_JSON" to px-status
        goback
    end-if
    move ws-value-node to ws-tools-node
    move 0 to ws-choice
    perform varying ws-loop from 1 by 1 until ws-loop > px-json-count
        if px-json-parent(ws-loop) = ws-tools-node
            move ws-loop to ws-choice
            exit perform
        end-if
    end-perform
    if ws-choice = 0
        move "PROVIDER_JSON" to px-status
        goback
    end-if
    move ws-choice to ws-parent
    move "message" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = 'O'
        move "PROVIDER_JSON" to px-status
        goback
    end-if
    move ws-value-node to ws-message
    move ws-message to ws-parent
    move "content" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'S'
        move px-json-value(ws-value-node) to px-answer
        move px-json-value-length(ws-value-node) to px-answer-length
    end-if
    move ws-message to ws-parent
    move "tool_calls" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'A'
        move ws-value-node to ws-tools-node
        perform varying ws-loop from 1 by 1
            until ws-loop > px-json-count
                or px-call-count >= 8
            if px-json-parent(ws-loop) not = ws-tools-node
                exit perform cycle
            end-if
            if px-json-kind(ws-loop) not = 'O' exit perform cycle end-if
            add 1 to px-call-count
            move ws-loop to ws-parent
            move "id" to ws-key
            perform find-field
            if ws-found = 1 and px-json-kind(ws-value-node) = 'S'
                move px-json-value(ws-value-node) to
                    px-call-id(px-call-count)
            end-if
            move ws-loop to ws-parent
            move "function" to ws-key
            perform find-field
            if ws-found = 1 and px-json-kind(ws-value-node) = 'O'
                move ws-value-node to ws-node
                move ws-node to ws-parent
                move "name" to ws-key
                perform find-field
                if ws-found = 1 and px-json-kind(ws-value-node) = 'S'
                    move px-json-value(ws-value-node) to
                        px-call-name(px-call-count)
                end-if
                move ws-node to ws-parent
                move "arguments" to ws-key
                perform find-field
                if ws-found = 1 and px-json-kind(ws-value-node) = 'S'
                    move px-json-value(ws-value-node) to
                        px-call-input(px-call-count)
                    move px-json-value-length(ws-value-node) to
                        px-call-input-length(px-call-count)
                end-if
            end-if
        end-perform
    end-if
    move 1 to ws-parent
    move "usage" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'O'
        move ws-value-node to ws-node
        move ws-node to ws-parent
        move "prompt_tokens" to ws-key
        perform find-field
        if ws-found = 1 and px-json-kind(ws-value-node) = 'N'
            move function numval(px-json-value(ws-value-node))
                to px-input-tokens
        end-if
        move ws-node to ws-parent
        move "completion_tokens" to ws-key
        perform find-field
        if ws-found = 1 and px-json-kind(ws-value-node) = 'N'
            move function numval(px-json-value(ws-value-node))
                to px-output-tokens
        end-if
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
            move "PROVIDER_JSON" to px-status
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
        move "PROVIDER_JSON" to px-status
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
end program praxo-openai.
