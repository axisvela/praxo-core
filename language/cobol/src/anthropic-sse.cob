       >>source format free
identification division.
program-id. praxo-anthropic-sse recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "sse-delta.cpy".
local-storage section.
copy "json.cpy".
01 ws-line-start binary-long.
01 ws-line-end binary-long.
01 ws-line-length binary-long.
01 ws-chunk-start binary-long.
01 ws-chunk-length binary-long.
01 ws-scan-index binary-long.
01 ws-parent binary-long.
01 ws-node binary-long.
01 ws-key pic x(64).
01 ws-found binary-long.
01 ws-value-node binary-long.
01 ws-index binary-long.
01 ws-slot binary-long.
01 ws-block binary-long.
01 ws-tool-count binary-long.
01 ws-search binary-long.
01 ws-tool-indexes occurs 8 times binary-long.
01 ws-slot-length binary-long.
01 ws-kind pic x(32).
01 ws-append-length binary-long.
01 ws-append-start binary-long.
01 ws-delta-status pic x(64).
01 ws-delta-length binary-long.
linkage section.
copy "sse.cpy".
procedure division using px-sse-request px-sse-result.
    initialize px-sse-result
    move 0 to ws-tool-count
    if px-sse-length < 0 or > 32768
        move "INVALID_REQUEST" to px-sse-error
        goback
    end-if
    move 1 to ws-line-start
    perform until ws-line-start > px-sse-length
        move ws-line-start to ws-line-end
        perform until ws-line-end > px-sse-length
            if px-sse-text(ws-line-end:1) = x"0a" exit perform end-if
            add 1 to ws-line-end
        end-perform
        compute ws-line-length = ws-line-end - ws-line-start
        perform process-line
        if px-sse-error not = spaces exit perform end-if
        if px-sse-done = 1 exit perform end-if
        if ws-line-end > px-sse-length exit perform end-if
        compute ws-line-start = ws-line-end + 1
    end-perform
    if px-sse-error = spaces and px-sse-done = 0
        move "MODEL_STREAM" to px-sse-error
    end-if
    goback.

process-line.
    perform trim-line
    if ws-line-length < 5 exit paragraph end-if
    if px-sse-text(ws-line-start:5) not = "data:" exit paragraph end-if
    compute ws-chunk-start = ws-line-start + 5
    compute ws-chunk-length = ws-line-length - 5
    perform trim-chunk-head
    perform trim-chunk-tail
    if ws-chunk-length = 0 exit paragraph end-if
    move px-sse-text(ws-chunk-start:ws-chunk-length) to px-json-text
    move ws-chunk-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move "MODEL_STREAM" to px-sse-error
        exit paragraph
    end-if
    add 1 to px-sse-event-count
    move 1 to ws-parent
    move "type" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "S"
        exit paragraph
    end-if
    move function trim(px-json-value(ws-value-node)) to ws-kind
    evaluate ws-kind
        when "message_start"
            perform handle-message-start
        when "content_block_start"
            perform handle-block-start
        when "content_block_delta"
            perform handle-block-delta
        when "message_delta"
            perform handle-message-delta
        when "message_stop"
            move 1 to px-sse-done
        when "error"
            move "MODEL_STREAM" to px-sse-error
    end-evaluate.

trim-line.
    perform until ws-line-length <= 0
        compute ws-scan-index = ws-line-start + ws-line-length - 1
        if px-sse-text(ws-scan-index:1) = x"0d"
            or px-sse-text(ws-scan-index:1) = spaces
            subtract 1 from ws-line-length
        else
            exit perform
        end-if
    end-perform.

trim-chunk-head.
    perform until ws-chunk-length <= 0
        if px-sse-text(ws-chunk-start:1) = spaces
            add 1 to ws-chunk-start
            subtract 1 from ws-chunk-length
        else
            exit perform
        end-if
    end-perform.

trim-chunk-tail.
    perform until ws-chunk-length <= 0
        compute ws-scan-index = ws-chunk-start + ws-chunk-length - 1
        if px-sse-text(ws-scan-index:1) = x"0d"
            or px-sse-text(ws-scan-index:1) = spaces
            subtract 1 from ws-chunk-length
        else
            exit perform
        end-if
    end-perform.

find-field.
    move 0 to ws-found
    perform varying ws-node from 1 by 1
        until ws-node > px-json-count
        if px-json-parent(ws-node) = ws-parent
            and px-json-kind(ws-node) = "K"
            and function trim(px-json-value(ws-node))
                = function trim(ws-key)
            compute ws-value-node = ws-node + 1
            if ws-value-node <= px-json-count
                move 1 to ws-found
            end-if
            exit perform
        end-if
    end-perform.

handle-message-start.
    move 1 to ws-parent
    move "message" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "O"
        exit paragraph
    end-if
    move ws-value-node to ws-parent
    move "usage" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "O"
        exit paragraph
    end-if
    move ws-value-node to ws-parent
    move "input_tokens" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = "N"
        move function numval(px-json-value(ws-value-node))
            to px-sse-input-tokens
    end-if.

handle-block-start.
    move 1 to ws-parent
    move "index" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "N"
        exit paragraph
    end-if
    compute ws-index = function numval(
        px-json-value(ws-value-node))
    move 1 to ws-parent
    move "content_block" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "O"
        exit paragraph
    end-if
    move ws-value-node to ws-block
    move ws-block to ws-parent
    move "type" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "S"
        exit paragraph
    end-if
    if function trim(px-json-value(ws-value-node)) not = "tool_use"
        exit paragraph
    end-if
    if ws-tool-count >= 8
        move "PROVIDER_JSON" to px-sse-error
        exit paragraph
    end-if
    add 1 to ws-tool-count
    move ws-tool-count to ws-slot
    move ws-index to ws-tool-indexes(ws-slot)
    move ws-tool-count to px-sse-tool-count
    move ws-block to ws-parent
    move "id" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = "S"
        move px-json-value-length(ws-value-node) to ws-slot-length
        if ws-slot-length > 64 move 64 to ws-slot-length end-if
        move px-json-value(ws-value-node)(1:ws-slot-length)
            to px-sse-call-id(ws-slot)(1:ws-slot-length)
    end-if
    move ws-block to ws-parent
    move "name" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = "S"
        move px-json-value-length(ws-value-node) to ws-slot-length
        if ws-slot-length > 64 move 64 to ws-slot-length end-if
        move px-json-value(ws-value-node)(1:ws-slot-length)
            to px-sse-call-name(ws-slot)(1:ws-slot-length)
    end-if.

handle-block-delta.
    move 1 to ws-parent
    move "index" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "N"
        exit paragraph
    end-if
    compute ws-index = function numval(
        px-json-value(ws-value-node))
    move 1 to ws-parent
    move "delta" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "O"
        exit paragraph
    end-if
    move ws-value-node to ws-parent
    move "type" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "S"
        exit paragraph
    end-if
    move function trim(px-json-value(ws-value-node)) to ws-kind
    if ws-kind = "text_delta"
        perform handle-text-delta
    else
        if ws-kind = "input_json_delta"
            move 0 to ws-slot
            perform varying ws-search from 1 by 1
                until ws-search > ws-tool-count or ws-slot > 0
                if ws-tool-indexes(ws-search) = ws-index
                    move ws-search to ws-slot
                end-if
            end-perform
            if ws-slot < 1 or ws-slot > 8
                exit paragraph
            end-if
            perform handle-json-delta
        end-if
    end-if.

handle-text-delta.
    move "text" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "S"
        exit paragraph
    end-if
    move px-json-value-length(ws-value-node) to ws-append-length
    if ws-append-length = 0 exit paragraph end-if
    compute ws-append-start = px-sse-content-length + 1
    if ws-append-start + ws-append-length - 1 > 32768
        exit paragraph
    end-if
    move px-json-value(ws-value-node)(1:ws-append-length)
        to px-sse-content(ws-append-start:ws-append-length)
    add ws-append-length to px-sse-content-length
    if px-sse-delta-program not = spaces
        if ws-append-length > 2048
            move 2048 to ws-delta-length
        else
            move ws-append-length to ws-delta-length
        end-if
        move px-json-value(ws-value-node)(1:ws-delta-length)
            to px-sse-delta-text(1:ws-delta-length)
        move ws-delta-length to px-sse-delta-length
        move spaces to ws-delta-status
        call px-sse-delta-program using px-sse-delta-call
            px-sse-user-data ws-delta-status
            on exception move "MODEL_STREAM" to ws-delta-status
        end-call
        if ws-delta-status not = spaces
            move ws-delta-status to px-sse-error
        end-if
    end-if.

handle-json-delta.
    move "partial_json" to ws-key
    perform find-field
    if ws-found = 0 or px-json-kind(ws-value-node) not = "S"
        exit paragraph
    end-if
    move px-json-value-length(ws-value-node) to ws-append-length
    if ws-append-length = 0 exit paragraph end-if
    move px-sse-call-arguments-length(ws-slot) to ws-slot-length
    if ws-slot-length + ws-append-length > 2048
        exit paragraph
    end-if
    compute ws-append-start = ws-slot-length + 1
    move px-json-value(ws-value-node)(1:ws-append-length)
        to px-sse-call-arguments(ws-slot)(ws-append-start:ws-append-length)
    add ws-append-length to px-sse-call-arguments-length(ws-slot).

handle-message-delta.
    move 1 to ws-parent
    move "delta" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = "O"
        move ws-value-node to ws-parent
        move "stop_reason" to ws-key
        perform find-field
        if ws-found = 1 and px-json-kind(ws-value-node) = "S"
            move px-json-value(ws-value-node) to px-sse-finish-reason
        end-if
    end-if
    move 1 to ws-parent
    move "usage" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = "O"
        move ws-value-node to ws-parent
        move "output_tokens" to ws-key
        perform find-field
        if ws-found = 1 and px-json-kind(ws-value-node) = "N"
            move function numval(px-json-value(ws-value-node))
                to px-sse-output-tokens
        end-if
    end-if.
end program praxo-anthropic-sse.
