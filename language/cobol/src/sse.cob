       >>source format free
identification division.
program-id. praxo-sse recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
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
                move 1 to px-sse-done
            end-if
        end-if
    end-perform.
end program praxo-sse.
