       >>source format free
identification division.
program-id. praxo-path-normalize recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 work-text pic x(4096).
01 work-length binary-long.
01 byte-index binary-long.
01 part-start binary-long.
01 part-length binary-long.
01 part-text pic x(1024).
01 parts occurs 128 times pic x(1024).
01 part-count binary-long.
01 absolute-path pic 9.
01 drive-path pic 9.
01 prefix pic x(8).
01 prefix-length binary-long.
01 first-char pic x.
01 position-index binary-long.
linkage section.
copy "path.cpy".
procedure division using px-path-request px-path-result.
    initialize px-path-result
    if px-path-length < 1 or > 4096
        move "INVALID_REQUEST" to px-path-error
        goback
    end-if
    move px-path-text(1:px-path-length) to work-text
    move px-path-length to work-length
    perform replace-backslashes
    perform classify-path
    if px-path-error not = spaces goback end-if
    perform split-path
    if px-path-error not = spaces goback end-if
    perform build-path
    goback.
replace-backslashes.
    perform varying byte-index from 1 by 1
        until byte-index > work-length
        if work-text(byte-index:1) = x"5c"
            move "/" to work-text(byte-index:1)
        end-if
    end-perform.
classify-path.
    move 0 to absolute-path drive-path
    move spaces to prefix
    move 0 to prefix-length
    if work-length >= 2
        if work-text(1:2) = "//"
            move "INVALID_REQUEST" to px-path-error
            exit paragraph
        end-if
    end-if
    if work-length >= 2
        if work-text(2:1) = ":"
            and not (work-length >= 3 and work-text(3:1) = "/")
            move "INVALID_REQUEST" to px-path-error
            exit paragraph
        end-if
    end-if
    if work-length >= 3
        if work-text(2:3) = ":/"
            move 1 to drive-path
            move 1 to absolute-path
            move work-text(1:1) to first-char
            if first-char >= "A" and <= "Z"
                inspect first-char converting
                    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" to
                    "abcdefghijklmnopqrstuvwxyz"
            end-if
            if first-char < "a" or > "z"
                move "INVALID_REQUEST" to px-path-error
                exit paragraph
            end-if
            move first-char to prefix(1:1)
            move ":/" to prefix(2:2)
            move 3 to prefix-length
            move 4 to part-start
            exit paragraph
        end-if
    end-if
    if work-text(1:1) = "/"
        move 1 to absolute-path
        move "/" to prefix(1:1)
        move 1 to prefix-length
        move 2 to part-start
    else
        move 1 to part-start
    end-if.
split-path.
    move 0 to part-count
    move part-start to byte-index
    perform until byte-index > work-length + 1
        if byte-index <= work-length
            if work-text(byte-index:1) not = "/"
                add 1 to byte-index
            else
                compute part-length = byte-index - part-start
                perform add-part
                if px-path-error not = spaces exit paragraph end-if
                compute part-start = byte-index + 1
                add 1 to byte-index
            end-if
        else
            compute part-length = byte-index - part-start
            perform add-part
            add 1 to byte-index
        end-if
    end-perform.
add-part.
    if part-length < 1 or > 1024 exit paragraph end-if
    move work-text(part-start:part-length) to part-text
    if part-length = 2 and part-text(1:2) = ".."
        if part-count > 0
            compute part-length = function length(function trim(
                parts(part-count) trailing))
            if part-length = 2 and parts(part-count)(1:2) = ".."
                if part-count >= 128
                    move "JSON_CAPACITY" to px-path-error
                    exit paragraph
                end-if
                add 1 to part-count
            else
                subtract 1 from part-count
            end-if
        else
            if absolute-path = 0
                if part-count >= 128
                    move "JSON_CAPACITY" to px-path-error
                    exit paragraph
                end-if
                add 1 to part-count
                move part-text to parts(part-count)
            end-if
        end-if
    else
        if part-length = 1 and part-text(1:1) = "."
            exit paragraph
        end-if
        if part-count >= 128
            move "JSON_CAPACITY" to px-path-error
            exit paragraph
        end-if
        add 1 to part-count
        move part-text to parts(part-count)
    end-if.
build-path.
    move spaces to px-path-normal
    move 0 to px-path-normal-length
    if prefix-length > 0
        move prefix(1:prefix-length) to px-path-normal(1:prefix-length)
        move prefix-length to px-path-normal-length
    end-if
    perform varying position-index from 1 by 1
        until position-index > part-count
        if px-path-normal-length > 0
            and px-path-normal(px-path-normal-length:1) not = "/"
            add 1 to px-path-normal-length
            move "/" to px-path-normal(px-path-normal-length:1)
        end-if
        compute part-length = function length(function trim(
            parts(position-index) trailing))
        add part-length to px-path-normal-length
        move parts(position-index)(1:part-length)
            to px-path-normal(
            px-path-normal-length - part-length + 1:part-length)
    end-perform
    if px-path-normal-length = 0
        move 1 to px-path-normal-length
        move "." to px-path-normal(1:1)
    end-if.
end program praxo-path-normalize.
