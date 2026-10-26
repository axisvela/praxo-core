       >>source format free
identification division.
program-id. praxo-toolcall recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
copy "json.cpy".
01 needle pic x(256).
01 needle-length binary-long.
01 search-start binary-long.
01 found-position binary-long.
01 scan-position binary-long.
01 last-position binary-long.
01 node-index binary-long.
01 name-node binary-long.
01 input-node binary-long.
01 tag-start binary-long.
01 tag-end binary-long.
01 name-start binary-long.
01 name-end binary-long.
01 name-text pic x(128).
01 name-length binary-long.
01 body-start binary-long.
01 body-length binary-long.
01 closing pic x(256).
01 closing-length binary-long.
01 dotted-valid pic 9.
01 dot-count binary-long.
01 name-position binary-long.
01 name-byte pic x.
01 output-position binary-long.
01 content-position binary-long.
01 recognized pic 9.
linkage section.
copy "toolcall.cpy".
procedure division using px-toolcall-request px-toolcall-result.
    initialize px-toolcall-result
    if px-tc-length < 0 or > 32768
        move "INVALID_REQUEST" to px-tc-error
        goback
    end-if
    evaluate px-tc-op
        when "parse" perform parse-call
        when "parse-input" perform parse-input
        when "strip" perform strip-markup
        when other move "INVALID_REQUEST" to px-tc-error
    end-evaluate
    goback.
parse-call.
    if px-tc-length = 0 exit paragraph end-if
    move px-tc-content to px-json-text
    move px-tc-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error = spaces and px-json-kind(1) = "O"
        perform parse-json-call
        if px-tc-found = 1 exit paragraph end-if
    end-if
    move 1 to content-position
    perform until content-position > px-tc-length
        move "<" to needle
        move 1 to needle-length
        move content-position to search-start
        perform find-text
        if found-position = 0 exit perform end-if
        move found-position to tag-start
        perform read-tag
        if tag-end = 0 exit perform end-if
        if recognized = 1
            move closing to needle
            move closing-length to needle-length
            compute search-start = tag-end + 1
            perform find-text
            if found-position > 0
                compute body-start = tag-end + 1
                compute body-length = found-position - body-start
                perform parse-body
                if px-tc-found = 1
                    move name-text to px-tc-name
                    move name-length to px-tc-name-length
                    exit paragraph
                end-if
            end-if
        end-if
        compute content-position = tag-end + 1
    end-perform
    perform parse-plain.
parse-json-call.
    move 0 to name-node input-node
    perform varying node-index from 2 by 1
        until node-index >= px-json-count
        if px-json-kind(node-index) = "K"
            and px-json-parent(node-index) = 1
            if px-json-value-length(node-index) = 4
                and px-json-value(node-index)(1:4) = "name"
                compute name-node = node-index + 1
            end-if
            if px-json-value-length(node-index) = 5
                and px-json-value(node-index)(1:5) = "input"
                compute input-node = node-index + 1
            end-if
        end-if
    end-perform
    if name-node = 0 exit paragraph end-if
    if px-json-kind(name-node) not = "S"
        or px-json-value-length(name-node) < 1 or > 128
        exit paragraph
    end-if
    move px-json-value(name-node) to name-text
    move px-json-value-length(name-node) to name-length
    if input-node > 0 and px-json-kind(input-node) = "O"
        move px-json-start(input-node) to body-start
        move px-json-size(input-node) to body-length
        perform parse-body
    else
        move "{}" to px-tc-input
        move 2 to px-tc-input-length
        move 1 to px-tc-found
    end-if
    if px-tc-found = 1
        move name-text to px-tc-name
        move name-length to px-tc-name-length
    end-if.
parse-input.
    move 1 to body-start
    move px-tc-length to body-length
    perform parse-body
    if px-tc-found = 0 move "JSON_INVALID" to px-tc-error end-if.
parse-body.
    if body-length < 1 or > 32768 exit paragraph end-if
    move px-tc-content(body-start:body-length) to px-json-text
    move body-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces exit paragraph end-if
    if px-json-kind(1) not = "O" exit paragraph end-if
    call "praxo-json-generate" using px-json-document px-json-output
        px-json-error
    if px-json-error not = spaces exit paragraph end-if
    move px-output-text to px-tc-input
    move px-output-length to px-tc-input-length
    move 1 to px-tc-found.
parse-plain.
    move 1 to name-start
    perform until name-start > px-tc-length
        if px-tc-content(name-start:1) not = space and x"09" and x"0a"
            and x"0d"
            exit perform
        end-if
        add 1 to name-start
    end-perform
    move name-start to name-end
    perform until name-end > px-tc-length
        if px-tc-content(name-end:1) = space or x"09" or x"0a" or x"0d"
            exit perform
        end-if
        add 1 to name-end
    end-perform
    compute name-length = name-end - name-start
    if name-length < 3 or > 128 exit paragraph end-if
    move px-tc-content(name-start:name-length) to name-text
    perform check-dotted-name
    if dotted-valid = 0 exit paragraph end-if
    move name-end to body-start
    compute body-length = px-tc-length - body-start + 1
    perform parse-body
    if px-tc-found = 1
        move name-text to px-tc-name
        move name-length to px-tc-name-length
    end-if.
read-tag.
    move 0 to tag-end recognized
    move ">" to needle
    move 1 to needle-length
    compute search-start = tag-start + 1
    perform find-text
    if found-position = 0 exit paragraph end-if
    move found-position to tag-end
    compute name-start = tag-start + 1
    compute name-length = tag-end - name-start
    if name-length < 1 or > 128 exit paragraph end-if
    move px-tc-content(name-start:name-length) to name-text
    if name-length >= 10 and name-text(1:10) = "tool_call "
        move 'name="' to needle
        move 6 to needle-length
        move name-start to search-start
        perform find-text
        if found-position = 0 exit paragraph end-if
        compute name-start = found-position + 6
        move '"' to needle
        move 1 to needle-length
        move name-start to search-start
        perform find-text
        if found-position = 0 or found-position >= tag-end
            exit paragraph
        end-if
        compute name-length = found-position - name-start
        if name-length < 1 or > 128 exit paragraph end-if
        move px-tc-content(name-start:name-length) to name-text
        move "</tool_call>" to closing
        move 12 to closing-length
        move 1 to recognized
        exit paragraph
    end-if
    if name-length = 16 and name-text(1:16) = "tool_call_invoke"
        move "</tool_call_invoke>" to closing
        move 19 to closing-length
        move 1 to recognized
        exit paragraph
    end-if
    perform check-dotted-name
    if dotted-valid = 1
        move spaces to closing
        string "</" name-text(1:name-length) ">"
            delimited by size into closing
        end-string
        compute closing-length = name-length + 3
        move 1 to recognized
    end-if.
check-dotted-name.
    move 0 to dotted-valid dot-count
    if name-length < 3 exit paragraph end-if
    if name-text(1:1) = "." or name-text(name-length:1) = "."
        exit paragraph
    end-if
    perform varying name-position from 1 by 1
        until name-position > name-length
        move name-text(name-position:1) to name-byte
        evaluate true
            when name-byte >= "a" and <= "z" continue
            when name-byte >= "A" and <= "Z" continue
            when name-byte >= "0" and <= "9" continue
            when name-byte = "_" or "-" continue
            when name-byte = "." add 1 to dot-count
            when other exit paragraph
        end-evaluate
    end-perform
    if dot-count > 0 move 1 to dotted-valid end-if.
strip-markup.
    move 1 to content-position output-position
    perform until content-position > px-tc-length
        move "<" to needle
        move 1 to needle-length
        move content-position to search-start
        perform find-text
        if found-position = 0
            compute body-length = px-tc-length - content-position + 1
            perform append-text
            exit perform
        end-if
        move found-position to tag-start
        compute body-length = tag-start - content-position
        perform append-text
        move tag-start to content-position
        perform read-tag
        if tag-end = 0
            compute body-length = px-tc-length - content-position + 1
            perform append-text
            exit perform
        end-if
        if recognized = 1
            move closing to needle
            move closing-length to needle-length
            compute search-start = tag-end + 1
            perform find-text
            if found-position = 0 exit perform end-if
            compute content-position = found-position + closing-length
        else
            compute body-length = tag-end - content-position + 1
            perform append-text
            compute content-position = tag-end + 1
        end-if
    end-perform
    move function trim(px-tc-text) to px-tc-text
    compute px-tc-text-length = function length(
        function trim(px-tc-text trailing)).
append-text.
    if body-length < 1 exit paragraph end-if
    string px-tc-content(content-position:body-length)
        delimited by size into px-tc-text with pointer output-position
    end-string.
find-text.
    move 0 to found-position
    compute last-position = px-tc-length - needle-length + 1
    perform varying scan-position from search-start by 1
        until scan-position > last-position
        if px-tc-content(scan-position:needle-length)
            = needle(1:needle-length)
            move scan-position to found-position
            exit perform
        end-if
    end-perform.
end program praxo-toolcall.
