       >>source format free
identification division.
program-id. praxo-schema-scalar recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
copy "json.cpy".
copy "pattern.cpy".
copy "slice.cpy".
01 search-name pic x(64).
01 search-name-length binary-long.
01 node-index binary-long.
01 found-node binary-long.
01 kind-text pic x(16).
01 kind-length binary-long.
01 min-length pic s9(15) comp-3.
01 max-length pic s9(15) comp-3.
01 min-set pic 9.
01 max-set pic 9.
01 pattern-text pic x(4096).
01 pattern-length binary-long.
01 minimum-value usage comp-2.
01 maximum-value usage comp-2.
01 minimum-set pic 9.
01 maximum-set pic 9.
01 enum-present pic 9.
01 enum-count binary-long.
01 enum-index binary-long.
01 enum-values occurs 32 times pic x(2048).
01 enum-lengths occurs 32 times binary-long.
01 saved-kind pic x.
01 saved-value pic x(2048).
01 saved-length binary-long.
01 saved-number usage comp-2.
01 number-value usage comp-2.
01 number-ok pic 9.
01 code-index binary-long.
01 code-count binary-long.
01 code-byte binary-long.
01 message-text pic x(128).
linkage section.
copy "scalar.cpy".
procedure division using px-scalar-request px-scalar-result.
    initialize px-scalar-result
    if px-scalar-schema-length < 1 or > 32768
        or px-scalar-data-length < 1 or > 32768
        or px-scalar-path-length < 1 or > 256
        move "INVALID_REQUEST" to px-scalar-error
        goback
    end-if
    move px-scalar-schema(1:px-scalar-schema-length) to px-json-text
    move px-scalar-schema-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move px-json-error to px-scalar-error
        goback
    end-if
    if px-json-kind(1) not = "O" goback end-if
    move "type" to search-name
    move 4 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node = 0 or px-json-kind(found-node) not = "S"
        goback
    end-if
    if px-json-value-length(found-node) > 16
        move "SCHEMA_UNSUPPORTED" to px-scalar-error
        goback
    end-if
    move px-json-value(found-node) to kind-text
    move px-json-value-length(found-node) to kind-length
    if kind-text(1:kind-length) = "object"
        or kind-text(1:kind-length) = "array"
        goback
    end-if
    move "minLength" to search-name
    move 9 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "N"
        compute min-length = function numval-f(
            px-json-value(found-node)(1:px-json-value-length(found-node)))
        if min-length > 0 move 1 to min-set end-if
    end-if
    move "maxLength" to search-name
    move 9 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "N"
        compute max-length = function numval-f(
            px-json-value(found-node)(1:px-json-value-length(found-node)))
        if max-length > 0 move 1 to max-set end-if
    end-if
    move "pattern" to search-name
    move 7 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "S"
        move px-json-value(found-node) to pattern-text
        move px-json-value-length(found-node) to pattern-length
    end-if
    move "minimum" to search-name
    move 7 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "N"
        compute minimum-value = function numval-f(
            px-json-value(found-node)(1:px-json-value-length(found-node)))
        if minimum-value not = 0 move 1 to minimum-set end-if
    end-if
    move "maximum" to search-name
    move 7 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "N"
        compute maximum-value = function numval-f(
            px-json-value(found-node)(1:px-json-value-length(found-node)))
        if maximum-value not = 0 move 1 to maximum-set end-if
    end-if
    move "enum" to search-name
    move 4 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "A"
        move 1 to enum-present
        move 0 to enum-count
        compute node-index = found-node
        perform until node-index >= px-json-count
            add 1 to node-index
            if px-json-parent(node-index) = found-node
                add 1 to enum-count
                if enum-count > 32
                    move "SCHEMA_CAPACITY" to px-scalar-error
                    goback
                end-if
                move px-scalar-schema(1:px-scalar-schema-length)
                    to px-slice-source
                move px-scalar-schema-length to px-slice-source-length
                compute px-slice-start = px-json-start(node-index)
                compute px-slice-size = px-json-size(node-index)
                call "praxo-json-slice" using px-slice-request
                    px-slice-result
                if px-slice-error not = spaces
                    move px-slice-error to px-scalar-error
                    goback
                end-if
                move px-slice-output(1:px-slice-output-length)
                    to enum-values(enum-count)
                move px-slice-output-length to enum-lengths(enum-count)
            end-if
        end-perform
    end-if
    move px-scalar-data(1:px-scalar-data-length) to px-json-text
    move px-scalar-data-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move px-json-error to px-scalar-error
        goback
    end-if
    if px-json-kind(1) = "Z"
        move "typed value cannot be null" to message-text
        perform add-error
        goback
    end-if
    evaluate kind-text(1:kind-length)
        when "string" perform check-string
        when "number" perform check-number
        when "integer" perform check-integer
        when "boolean" perform check-boolean
        when other continue
    end-evaluate
    goback.
check-string.
    if px-json-kind(1) not = "S"
        move "expected string" to message-text
        perform add-error
        exit paragraph
    end-if
    move 0 to code-count
    perform varying code-index from 1 by 1
        until code-index > px-json-value-length(1)
        compute code-byte = function ord(px-json-value(1)(code-index:1)) - 1
        if code-byte < 128 or code-byte >= 192
            add 1 to code-count
        end-if
    end-perform
    if min-set = 1 and code-count < min-length
        move "below minimum string length" to message-text
        perform add-error
    end-if
    if max-set = 1 and code-count > max-length
        move "above maximum string length" to message-text
        perform add-error
    end-if
    if pattern-length > 0
        move pattern-text(1:pattern-length) to px-pat-pattern
        move pattern-length to px-pat-pattern-length
        move px-json-value(1) to px-pat-text
        move px-json-value-length(1) to px-pat-text-length
        call "praxo-pattern-check" using px-pattern-request px-pattern-result
        if px-pat-error not = spaces
            move px-pat-error to px-scalar-error
            exit paragraph
        end-if
        if px-pat-matched = 0
            move "pattern not matched" to message-text
            perform add-error
        end-if
    end-if
    perform check-enum.
check-number.
    if px-json-kind(1) not = "N"
        move "expected number" to message-text
        perform add-error
        exit paragraph
    end-if
    perform numeric-value
    if number-ok = 0
        move "expected number" to message-text
        perform add-error
        exit paragraph
    end-if
    if minimum-set = 1 and number-value < minimum-value
        move "value below minimum" to message-text
        perform add-error
    end-if
    if maximum-set = 1 and number-value > maximum-value
        move "value above maximum" to message-text
        perform add-error
    end-if
    perform check-enum.
check-integer.
    if px-json-kind(1) not = "N"
        move "expected integer" to message-text
        perform add-error
        exit paragraph
    end-if
    perform numeric-value
    if number-ok = 0
        or number-value not = function integer(number-value)
        move "expected integer" to message-text
        perform add-error
        exit paragraph
    end-if
    if minimum-set = 1 and number-value < minimum-value
        move "value below minimum" to message-text
        perform add-error
    end-if
    if maximum-set = 1 and number-value > maximum-value
        move "value above maximum" to message-text
        perform add-error
    end-if
    perform check-enum.
check-boolean.
    if px-json-kind(1) not = "T" and not = "F"
        move "expected boolean" to message-text
        perform add-error
        exit paragraph
    end-if
    perform check-enum.
check-enum.
    if enum-present = 0 exit paragraph end-if
    move px-json-kind(1) to saved-kind
    move px-json-value(1) to saved-value
    move px-json-value-length(1) to saved-length
    if saved-kind = "N"
        compute saved-number = function numval-f(saved-value(1:saved-length))
    end-if
    perform varying enum-index from 1 by 1
        until enum-index > enum-count
        move enum-values(enum-index) to px-json-text
        move enum-lengths(enum-index) to px-json-length
        call "praxo-json-parse" using px-json-input px-json-document
            px-json-error
        if px-json-error not = spaces
            move px-json-error to px-scalar-error
            exit paragraph
        end-if
        if px-json-kind(1) = saved-kind
            evaluate saved-kind
                when "N"
                    compute number-value = function numval-f(
                        px-json-value(1)(1:px-json-value-length(1)))
                    if number-value = saved-number exit paragraph end-if
                when "S"
                    if saved-length = px-json-value-length(1)
                        if saved-length = 0 exit paragraph end-if
                        if saved-value(1:saved-length)
                            = px-json-value(1)(1:saved-length)
                            exit paragraph
                        end-if
                    end-if
                when "T" when "F" exit paragraph
                when other exit paragraph
            end-evaluate
        end-if
    end-perform
    move "value not in enum" to message-text
    perform add-error.
numeric-value.
    move 0 to number-ok
    if px-json-value-length(1) < 1 or > 2048 exit paragraph end-if
    compute number-value = function numval-f(
        px-json-value(1)(1:px-json-value-length(1)))
    move 1 to number-ok.
find-member.
    move 0 to found-node
    compute node-index = 1
    perform until node-index >= px-json-count - 1
        add 1 to node-index
        if px-json-parent(node-index) = 1
            and px-json-kind(node-index) = "K"
            and px-json-value-length(node-index) = search-name-length
            and px-json-value(node-index)(1:search-name-length)
                = search-name(1:search-name-length)
            compute found-node = node-index + 1
        end-if
    end-perform.
add-error.
    if px-scalar-count >= 64
        move "SCHEMA_CAPACITY" to px-scalar-error
        exit paragraph
    end-if
    add 1 to px-scalar-count
    move px-scalar-path(1:px-scalar-path-length)
        to px-scalar-error-path(px-scalar-count)
    move message-text to px-scalar-error-message(px-scalar-count).
end program praxo-schema-scalar.
