       >>source format free
identification division.
program-id. praxo-sse recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "sse-delta.cpy".
local-storage section.
copy "json.cpy".
01 line-start binary-long.
01 line-end binary-long.
01 line-length binary-long.
01 chunk-start binary-long.
01 chunk-length binary-long.
01 scan-index binary-long.
01 node-index binary-long.
01 value-index binary-long.
01 content-start binary-long.
01 append-length binary-long.
01 delta-status pic x(64).
01 delta-length binary-long.
01 tool-node binary-long.
01 tool-child binary-long.
01 tool-field binary-long.
01 tool-function binary-long.
01 tool-slot binary-long.
01 tool-index binary-long.
01 tool-length binary-long.
01 tool-slot-length binary-long.
01 tool-found binary-long.
01 usage-node binary-long.
linkage section.
copy "sse.cpy".
procedure division using px-sse-request px-sse-result.
    initialize px-sse-result
    if px-sse-length < 0 or > 32768
        move "INVALID_REQUEST" to px-sse-error
        goback
    end-if
    move 1 to line-start
    perform until line-start > px-sse-length
        move line-start to line-end
        perform until line-end > px-sse-length
            if px-sse-text(line-end:1) = x"0a" exit perform end-if
            add 1 to line-end
        end-perform
        compute line-length = line-end - line-start
        perform process-line
        if px-sse-error not = spaces exit perform end-if
        if px-sse-done = 1 exit perform end-if
        if line-end > px-sse-length exit perform end-if
        compute line-start = line-end + 1
    end-perform
    if px-sse-error = spaces and px-sse-done = 0
        move "MODEL_STREAM" to px-sse-error
    end-if
    goback.

process-line.
    perform trim-line
    if line-length < 5 exit paragraph end-if
    if px-sse-text(line-start:5) not = "data:" exit paragraph end-if
    compute chunk-start = line-start + 5
    compute chunk-length = line-length - 5
    perform trim-chunk-head
    perform trim-chunk-tail
    if chunk-length = 0 exit paragraph end-if
    if chunk-length = 6
        and px-sse-text(chunk-start:6) = "[DONE]"
        move 1 to px-sse-done
        exit paragraph
    end-if
    move px-sse-text(chunk-start:chunk-length) to px-json-text
    move chunk-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move "MODEL_STREAM" to px-sse-error
        exit paragraph
    end-if
    add 1 to px-sse-event-count
    perform extract-content
    perform extract-tools
    perform extract-usage
    perform extract-finish.

trim-line.
    perform until line-length <= 0
        compute scan-index = line-start + line-length - 1
        if px-sse-text(scan-index:1) = x"0d"
            or px-sse-text(scan-index:1) = spaces
            subtract 1 from line-length
        else
            exit perform
        end-if
    end-perform.

trim-chunk-head.
    perform until chunk-length <= 0
        if px-sse-text(chunk-start:1) = spaces
            add 1 to chunk-start
            subtract 1 from chunk-length
        else
            exit perform
        end-if
    end-perform.

trim-chunk-tail.
    perform until chunk-length <= 0
        compute scan-index = chunk-start + chunk-length - 1
        if px-sse-text(scan-index:1) = x"0d"
            or px-sse-text(scan-index:1) = spaces
            subtract 1 from chunk-length
        else
            exit perform
        end-if
    end-perform.

extract-content.
    perform varying node-index from 2 by 1
        until node-index > px-json-count
        if px-json-kind(node-index) = "K"
            and px-json-value-length(node-index) = 7
            and px-json-value(node-index)(1:7) = "content"
            compute value-index = node-index + 1
            if value-index <= px-json-count
                and px-json-kind(value-index) = "S"
                move px-json-value-length(value-index)
                    to append-length
                compute content-start = px-sse-content-length + 1
                if append-length > 0
                    and content-start + append-length - 1 <= 32768
                    move px-json-value(value-index)(1:append-length)
                        to px-sse-content(content-start:append-length)
                    add append-length to px-sse-content-length
                    if px-sse-delta-program not = spaces
                        if append-length > 2048
                            move 2048 to delta-length
                        else
                            move append-length to delta-length
                        end-if
                        move px-json-value(value-index)(1:delta-length)
                            to px-sse-delta-text(1:delta-length)
                        move delta-length to px-sse-delta-length
                        move spaces to delta-status
                        call px-sse-delta-program using px-sse-delta-call
                            px-sse-user-data delta-status
                            on exception
                                move "MODEL_STREAM" to delta-status
                        end-call
                        if delta-status not = spaces
                            move delta-status to px-sse-error
                        end-if
                    end-if
                end-if
            end-if
        end-if
    end-perform.

extract-finish.
    perform varying node-index from 2 by 1
        until node-index > px-json-count
        if px-json-kind(node-index) = "K"
            and px-json-value-length(node-index) = 13
            and px-json-value(node-index)(1:13) = "finish_reason"
            compute value-index = node-index + 1
            if value-index <= px-json-count
                and px-json-kind(value-index) not = "Z"
                move px-json-value(value-index)
                    to px-sse-finish-reason
                move 1 to px-sse-done
            end-if
        end-if
    end-perform.

extract-tools.
    perform varying tool-node from 2 by 1
        until tool-node > px-json-count or px-sse-error not = spaces
        if px-json-kind(tool-node) = "K"
            and px-json-value-length(tool-node) = 10
            and px-json-value(tool-node)(1:10) = "tool_calls"
            compute value-index = tool-node + 1
            if value-index <= px-json-count
                and px-json-kind(value-index) = "A"
                move value-index to tool-node
            else
                exit perform cycle
            end-if
            perform varying tool-child from 2 by 1
                until tool-child > px-json-count
                    or px-sse-error not = spaces
                if px-json-parent(tool-child) not = tool-node
                    exit perform cycle
                end-if
                if px-json-kind(tool-child) not = "O"
                    exit perform cycle
                end-if
                compute tool-slot = px-sse-tool-count + 1
                move 0 to tool-found tool-function
                perform find-tool-index
                if tool-slot < 1 or tool-slot > 8
                    move "PROVIDER_JSON" to px-sse-error
                    exit perform
                end-if
                move 0 to tool-function
                perform find-tool-function
                perform append-tool-fields
                if tool-slot > px-sse-tool-count
                    move tool-slot to px-sse-tool-count
                end-if
            end-perform
        end-if
    end-perform.

find-tool-index.
    perform varying tool-field from 2 by 1
        until tool-field > px-json-count
        if px-json-parent(tool-field) = tool-child
            and px-json-kind(tool-field) = "K"
            and px-json-value-length(tool-field) = 5
            and px-json-value(tool-field)(1:5) = "index"
            compute value-index = tool-field + 1
            if value-index <= px-json-count
                and px-json-kind(value-index) = "N"
                compute tool-slot = function numval(
                    px-json-value(value-index)) + 1
                move 1 to tool-found
            end-if
            exit perform
        end-if
    end-perform.

find-tool-function.
    perform varying tool-field from 2 by 1
        until tool-field > px-json-count
        if px-json-parent(tool-field) = tool-child
            and px-json-kind(tool-field) = "K"
            and px-json-value-length(tool-field) = 8
            and px-json-value(tool-field)(1:8) = "function"
            compute value-index = tool-field + 1
            if value-index <= px-json-count
                and px-json-kind(value-index) = "O"
                move value-index to tool-function
            end-if
            exit perform
        end-if
    end-perform.

append-tool-fields.
    perform varying tool-field from 2 by 1
        until tool-field > px-json-count
        if px-json-kind(tool-field) = "K"
            compute value-index = tool-field + 1
            if value-index > px-json-count
                exit perform cycle
            end-if
            if px-json-parent(tool-field) = tool-child
                and px-json-value-length(tool-field) = 2
                and px-json-value(tool-field)(1:2) = "id"
                and px-json-kind(value-index) = "S"
                perform append-tool-id
            end-if
            if tool-function > 0
                and px-json-parent(tool-field) = tool-function
                if px-json-value-length(tool-field) = 4
                    and px-json-value(tool-field)(1:4) = "name"
                    and px-json-kind(value-index) = "S"
                    perform append-tool-name
                end-if
                if px-json-value-length(tool-field) = 9
                    and px-json-value(tool-field)(1:9) = "arguments"
                    and px-json-kind(value-index) = "S"
                    perform append-tool-arguments
                end-if
            end-if
        end-if
    end-perform.

append-tool-id.
    move px-json-value-length(value-index) to tool-length
    if tool-length > 64 move 64 to tool-length end-if
    compute tool-slot-length = function length(
        function trim(px-sse-call-id(tool-slot)))
    if tool-slot-length + tool-length <= 64
        move px-json-value(value-index)(1:tool-length)
            to px-sse-call-id(tool-slot)(
                tool-slot-length + 1:tool-length)
    end-if.

append-tool-name.
    move px-json-value-length(value-index) to tool-length
    if tool-length > 64 move 64 to tool-length end-if
    compute tool-slot-length = function length(
        function trim(px-sse-call-name(tool-slot)))
    if tool-slot-length + tool-length <= 64
        move px-json-value(value-index)(1:tool-length)
            to px-sse-call-name(tool-slot)(
                tool-slot-length + 1:tool-length)
    end-if.

append-tool-arguments.
    move px-json-value-length(value-index) to tool-length
    if tool-length > 2048 move 2048 to tool-length end-if
    move px-sse-call-arguments-length(tool-slot)
        to tool-slot-length
    if tool-slot-length + tool-length <= 2048
        move px-json-value(value-index)(1:tool-length)
            to px-sse-call-arguments(tool-slot)(
                tool-slot-length + 1:tool-length)
        add tool-length to
            px-sse-call-arguments-length(tool-slot)
    end-if.

extract-usage.
    perform varying usage-node from 2 by 1
        until usage-node > px-json-count
        if px-json-kind(usage-node) = "K"
            and px-json-value-length(usage-node) = 5
            and px-json-value(usage-node)(1:5) = "usage"
            compute value-index = usage-node + 1
            if value-index <= px-json-count
                and px-json-kind(value-index) = "O"
                move value-index to usage-node
            else
                exit perform cycle
            end-if
            perform varying tool-field from 2 by 1
                until tool-field > px-json-count
                if px-json-parent(tool-field) not = usage-node
                    exit perform cycle
                end-if
                if px-json-kind(tool-field) = "K"
                    compute value-index = tool-field + 1
                    if value-index <= px-json-count
                        and px-json-kind(value-index) = "N"
                        if px-json-value-length(tool-field) = 13
                            and px-json-value(tool-field)(1:13) =
                                "prompt_tokens"
                            move function numval(
                                px-json-value(value-index))
                                to px-sse-input-tokens
                        end-if
                        if px-json-value-length(tool-field) = 17
                            and px-json-value(tool-field)(1:17) =
                                "completion_tokens"
                            move function numval(
                                px-json-value(value-index))
                                to px-sse-output-tokens
                        end-if
                    end-if
                end-if
            end-perform
        end-if
    end-perform.
end program praxo-sse.
