       >>source format free
identification division.
program-id. praxo-anthropic recursive.
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
01 ws-system pic x(8192).
01 ws-system-position binary-long.
01 ws-system-length binary-long.
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
01 ws-number pic z(9).
01 ws-text pic x(2048).
01 ws-text-length binary-long.
local-storage section.
copy "anthropic-call.cpy".
copy "json.cpy".
linkage section.
copy "anthropic-options.cpy".
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
procedure division using px-anthropic-options px-session px-response
    px-user-data px-status.
    initialize px-response
    move spaces to px-status
    if function trim(px-anthropic-base-url) = spaces
        or function trim(px-anthropic-model) = spaces
        move "PROVIDER_HTTP" to px-status
        goback
    end-if
    if px-anthropic-transport-program = spaces
        move "PROVIDER_HTTP" to px-status
        goback
    end-if
    if px-message-count < 0 or px-message-count > 64
        move "PROVIDER_JSON" to px-status
        goback
    end-if
    perform build-system
    perform build-body
    if px-status not = spaces goback end-if
    move function trim(px-anthropic-base-url) to ws-url
    compute ws-url-length = function length(
        function trim(px-anthropic-base-url))
    perform until ws-url-length = 0
        if ws-url(ws-url-length:1) not = "/" exit perform end-if
        subtract 1 from ws-url-length
    end-perform
    compute ws-piece-length = ws-url-length + 1
    move "/messages" to ws-url(ws-piece-length:9)
    add 9 to ws-url-length
    move ws-url to px-anthropic-url
    move ws-url-length to px-anthropic-url-length
    move "POST" to px-anthropic-method
    move "application/json" to px-anthropic-content-type
    move px-anthropic-api-key to px-anthropic-send-key
    move px-anthropic-api-key-length to
        px-anthropic-send-key-length
    if function trim(px-anthropic-version) = spaces
        move "2023-06-01" to px-anthropic-call-version
    else
        move function trim(px-anthropic-version) to
            px-anthropic-call-version
    end-if
    move ws-body to px-anthropic-body
    compute px-anthropic-body-length = ws-body-position - 1
    move 0 to px-anthropic-status-code
    move spaces to px-anthropic-response
    move 0 to px-anthropic-response-length
    call px-anthropic-transport-program using px-anthropic-call
        px-user-data px-status
    if px-status not = spaces goback end-if
    if px-anthropic-status-code < 200
        or px-anthropic-status-code >= 300
        move "PROVIDER_HTTP" to px-status
        goback
    end-if
    move px-anthropic-response to px-json-text
    move px-anthropic-response-length to px-json-length
    move spaces to px-json-error
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces or px-json-count < 1
        or px-json-kind(1) not = 'O'
        move "PROVIDER_JSON" to px-status
        goback
    end-if
    move 1 to ws-parent
    move "content" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = 'A'
        move "PROVIDER_JSON" to px-status
        goback
    end-if
    move ws-value-node to ws-node
    perform varying ws-loop from 1 by 1 until ws-loop > px-json-count
        if px-json-parent(ws-loop) not = ws-node exit perform cycle end-if
        if px-json-kind(ws-loop) not = 'O' exit perform cycle end-if
        move ws-loop to ws-parent
        move "type" to ws-key
        perform find-field
        if ws-found = 1 and px-json-kind(ws-value-node) = 'S'
            if function trim(px-json-value(ws-value-node)) = "text"
                perform append-text-block
            else
                if function trim(px-json-value(ws-value-node))
                    = "tool_use"
                    perform append-tool-block
                end-if
            end-if
        end-if
    end-perform
    if px-status not = spaces goback end-if
    move 1 to ws-parent
    move "usage" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'O'
        move ws-value-node to ws-node
        move ws-node to ws-parent
        move "input_tokens" to ws-key
        perform find-field
        if ws-found = 1 and px-json-kind(ws-value-node) = 'N'
            move function numval(px-json-value(ws-value-node))
                to px-input-tokens
        end-if
        move ws-node to ws-parent
        move "output_tokens" to ws-key
        perform find-field
        if ws-found = 1 and px-json-kind(ws-value-node) = 'N'
            move function numval(px-json-value(ws-value-node))
                to px-output-tokens
        end-if
    end-if
    goback.
build-system.
    move spaces to ws-system
    move 1 to ws-system-position
    perform varying ws-loop from 1 by 1
        until ws-loop > px-message-count
        if function trim(px-role(ws-loop)) = "system"
            if px-content-length(ws-loop) > 0
                if ws-system-position > 1
                    move " " to ws-system(ws-system-position:1)
                    add 1 to ws-system-position
                end-if
                if ws-system-position + px-content-length(ws-loop) - 1
                    > 8192
                    move "PROVIDER_JSON" to px-status
                    exit paragraph
                end-if
                move px-content(ws-loop)(1:px-content-length(ws-loop))
                    to ws-system(ws-system-position:
                    px-content-length(ws-loop))
                add px-content-length(ws-loop) to ws-system-position
            end-if
        end-if
    end-perform
    compute ws-system-length = ws-system-position - 1.
build-body.
    move 2 to ws-body-position
    move "{" to ws-body
    move '"model":' to ws-literal
    perform append-literal
    move function trim(px-anthropic-model) to ws-source
    compute ws-source-length = function length(
        function trim(px-anthropic-model))
    perform quote-source
    if px-status not = spaces exit paragraph end-if
    move ',"max_tokens":' to ws-literal
    perform append-literal
    if px-anthropic-max-tokens <= 0
        move 1024 to ws-number
    else
        move px-anthropic-max-tokens to ws-number
    end-if
    move function trim(ws-number) to ws-source
    compute ws-source-length = function length(
        function trim(ws-number))
    move ws-source(1:ws-source-length) to ws-piece
    move ws-source-length to ws-piece-length
    perform append-piece
    if ws-system-length > 0
        move ',"system":' to ws-literal
        perform append-literal
        move ws-system to ws-source
        move ws-system-length to ws-source-length
        perform quote-source
        if px-status not = spaces exit paragraph end-if
    end-if
    move ',"messages":[' to ws-literal
    perform append-literal
    move 0 to ws-index
    perform varying ws-loop from 1 by 1
        until ws-loop > px-message-count
        or px-status not = spaces
        if function trim(px-role(ws-loop)) = "system"
            exit perform cycle
        end-if
        if ws-index > 0
            move "," to ws-literal
            perform append-literal
        end-if
        add 1 to ws-index
        move '{"role":' to ws-literal
        perform append-literal
        move function trim(px-role(ws-loop)) to ws-source
        compute ws-source-length = function length(
            function trim(px-role(ws-loop)))
        perform quote-source
        if px-status not = spaces exit paragraph end-if
        move ',"content":' to ws-literal
        perform append-literal
        move px-content(ws-loop) to ws-source
        move px-content-length(ws-loop) to ws-source-length
        perform quote-source
        if px-status not = spaces exit paragraph end-if
        move "}" to ws-literal
        perform append-literal
    end-perform
    if px-status not = spaces exit paragraph end-if
    move "]" to ws-literal
    perform append-literal
    if px-anthropic-tools-length > 0
        move ',"tools":' to ws-literal
        perform append-literal
        move px-anthropic-tools-length to ws-piece-length
        move px-anthropic-tools to ws-piece
        perform append-piece
        if px-status not = spaces exit paragraph end-if
    end-if
    if px-anthropic-tool-choice-length > 0
        and function trim(px-anthropic-tool-choice) not = spaces
        move ',"tool_choice":' to ws-literal
        perform append-literal
        if function trim(px-anthropic-tool-choice) = "auto"
            move '{"type":"auto"}' to ws-literal
            perform append-literal
        else
            if function trim(px-anthropic-tool-choice) = "any"
                move '{"type":"any"}' to ws-literal
                perform append-literal
            else
                if px-anthropic-tool-choice(1:1) = "{"
                    or px-anthropic-tool-choice(1:1) = '"'
                    move px-anthropic-tool-choice-length to
                        ws-piece-length
                    move px-anthropic-tool-choice to ws-piece
                    perform append-piece
                else
                    move '{"type":"tool","name":' to ws-literal
                    perform append-literal
                    move function trim(px-anthropic-tool-choice) to
                        ws-source
                    compute ws-source-length = function length(
                        function trim(px-anthropic-tool-choice))
                    perform quote-source
                    move "}" to ws-literal
                    perform append-literal
                end-if
            end-if
        end-if
        if px-status not = spaces exit paragraph end-if
    end-if
    move "}" to ws-literal
    perform append-literal.
append-text-block.
    move ws-loop to ws-parent
    move "text" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = 'S'
        move "PROVIDER_JSON" to px-status
        exit paragraph
    end-if
    move px-json-value(ws-value-node) to ws-text
    move px-json-value-length(ws-value-node) to ws-text-length
    if px-answer-length + ws-text-length > 2048
        move "PROVIDER_JSON" to px-status
        exit paragraph
    end-if
    if ws-text-length > 0
        move ws-text(1:ws-text-length) to
            px-answer(px-answer-length + 1:ws-text-length)
        add ws-text-length to px-answer-length
    end-if.
append-tool-block.
    if px-call-count >= 8
        move "PROVIDER_JSON" to px-status
        exit paragraph
    end-if
    add 1 to px-call-count
    move ws-loop to ws-parent
    move "id" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'S'
        move px-json-value(ws-value-node) to
            px-call-id(px-call-count)
    end-if
    move ws-loop to ws-parent
    move "name" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'S'
        move px-json-value(ws-value-node) to
            px-call-name(px-call-count)
    end-if
    move ws-loop to ws-parent
    move "input" to ws-key
    perform find-field
    if ws-found = 1
        move ws-value-node to ws-node
        perform raw-node
        move ws-raw to px-call-input(px-call-count)
        move ws-raw-length to px-call-input-length(px-call-count)
    end-if.
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
raw-node.
    move spaces to ws-raw
    move 0 to ws-raw-length
    if ws-node < 1 or ws-node > px-json-count goback end-if
    move px-json-start(ws-node) to ws-start
    move px-json-size(ws-node) to ws-size
    if ws-size < 1 or ws-start < 1 goback end-if
    compute ws-end = ws-start + ws-size - 1
    if ws-end > px-json-length goback end-if
    if ws-size > 8192
        move 8192 to ws-size
    end-if
    move px-json-text(ws-start:ws-size) to ws-raw
    move ws-size to ws-raw-length.
end program praxo-anthropic.
