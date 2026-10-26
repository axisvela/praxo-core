       >>source format free
identification division.
program-id. praxo-schema-visit recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
copy "json.cpy".
copy "slice.cpy".
copy "scalar.cpy".
01 child-request.
   05 child-schema pic x(32768).
   05 child-schema-length binary-long.
   05 child-data pic x(32768).
   05 child-data-length binary-long.
   05 child-path pic x(256).
   05 child-path-length binary-long.
01 current-source pic x(32768).
01 current-source-length binary-long.
01 schema-kind pic x(16).
01 schema-kind-length binary-long.
01 property-count binary-long.
01 property-names occurs 32 times pic x(128).
01 property-name-lengths occurs 32 times binary-long.
01 property-schemas occurs 32 times pic x(16384).
01 property-schema-lengths occurs 32 times binary-long.
01 required-count binary-long.
01 required-names occurs 32 times pic x(128).
01 required-name-lengths occurs 32 times binary-long.
01 items-schema pic x(16384).
01 items-schema-length binary-long.
01 items-present pic 9.
01 node-index binary-long.
01 find-index binary-long.
01 child-index binary-long.
01 found-node binary-long.
01 value-node binary-long.
01 gen-output pic x(16384).
01 gen-length binary-long.
01 data-output pic x(16384).
01 data-length binary-long.
01 index-edited pic z(9)9.
01 search-name pic x(128).
01 search-name-length binary-long.
01 old-path pic x(256).
01 old-path-length binary-long.
01 message-text pic x(128).
linkage section.
copy "visit.cpy".
copy "schema.cpy".
procedure division using px-visit-request px-schema-result.
    if px-visit-schema-length < 1 or > 32768
        or px-visit-data-length < 1 or > 32768
        or px-visit-path-length < 1 or > 256
        move "INVALID_REQUEST" to px-sch-error
        goback
    end-if
    perform load-schema
    if px-sch-error not = spaces goback end-if
    perform load-data
    if px-sch-error not = spaces goback end-if
    if schema-kind-length = 0 goback end-if
    if px-json-kind(1) = "Z"
        move "typed value cannot be null" to message-text
        perform add-error
        goback
    end-if
    evaluate schema-kind(1:schema-kind-length)
        when "object" perform validate-object
        when "array" perform validate-array
        when other perform delegate-scalar
    end-evaluate
    goback.
load-schema.
    move px-visit-schema(1:px-visit-schema-length) to current-source
    move px-visit-schema-length to current-source-length
    move px-visit-schema(1:px-visit-schema-length) to px-json-text
    move px-visit-schema-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document px-json-error
    if px-json-error not = spaces
        move px-json-error to px-sch-error
        exit paragraph
    end-if
    if px-json-kind(1) not = "O" exit paragraph end-if
    move spaces to schema-kind
    move 0 to schema-kind-length
    move "type" to search-name
    move 4 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "S"
        move px-json-value(found-node) to schema-kind
        move px-json-value-length(found-node) to schema-kind-length
        if schema-kind-length > 16
            move "SCHEMA_UNSUPPORTED" to px-sch-error
            exit paragraph
        end-if
    end-if
    if schema-kind-length = 0 exit paragraph end-if
    evaluate schema-kind(1:schema-kind-length)
        when "object" perform load-object-rules
        when "array" perform load-array-rules
        when other continue
    end-evaluate.
load-object-rules.
    move "required" to search-name
    move 8 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "A"
        move 0 to required-count
        compute child-index = found-node
        perform until child-index >= px-json-count
            add 1 to child-index
            if px-json-parent(child-index) = found-node
                and px-json-kind(child-index) = "S"
                if required-count >= 32
                    or px-json-value-length(child-index) < 1
                    or > 128
                    move "SCHEMA_CAPACITY" to px-sch-error
                    exit paragraph
                end-if
                add 1 to required-count
                move px-json-value(child-index)
                    to required-names(required-count)
                move px-json-value-length(child-index)
                    to required-name-lengths(required-count)
            end-if
        end-perform
    end-if
    move "properties" to search-name
    move 10 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0 and px-json-kind(found-node) = "O"
        move 0 to property-count
        compute child-index = found-node
        perform until child-index >= px-json-count
            add 1 to child-index
            if px-json-parent(child-index) = found-node
                and px-json-kind(child-index) = "K"
                if property-count >= 32
                    or px-json-value-length(child-index) < 1
                    or > 128
                    move "SCHEMA_CAPACITY" to px-sch-error
                    exit paragraph
                end-if
                add 1 to property-count
                move px-json-value(child-index)
                    to property-names(property-count)
                move px-json-value-length(child-index)
                    to property-name-lengths(property-count)
                compute value-node = child-index + 1
                move value-node to node-index
                perform slice-node
                if px-json-error not = spaces
                    move px-json-error to px-sch-error
                    exit paragraph
                end-if
                move gen-output(1:gen-length)
                    to property-schemas(property-count)
                move gen-length to property-schema-lengths(property-count)
            end-if
        end-perform
    end-if.
load-array-rules.
    move "items" to search-name
    move 5 to search-name-length
    move 1 to node-index
    perform find-member
    if found-node > 0
        move found-node to node-index
        perform slice-node
        if px-json-error not = spaces
            move px-json-error to px-sch-error
            exit paragraph
        end-if
        move gen-output(1:gen-length) to items-schema
        move gen-length to items-schema-length
        move 1 to items-present
    end-if.
load-data.
    move px-visit-data(1:px-visit-data-length) to current-source
    move px-visit-data-length to current-source-length
    move px-visit-data(1:px-visit-data-length) to px-json-text
    move px-visit-data-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document px-json-error
    if px-json-error not = spaces
        move px-json-error to px-sch-error
    end-if.
delegate-scalar.
    move px-visit-schema(1:px-visit-schema-length) to px-scalar-schema
    move px-visit-schema-length to px-scalar-schema-length
    move px-visit-data(1:px-visit-data-length) to px-scalar-data
    move px-visit-data-length to px-scalar-data-length
    move px-visit-path(1:px-visit-path-length) to px-scalar-path
    move px-visit-path-length to px-scalar-path-length
    call "praxo-schema-scalar" using px-scalar-request px-scalar-result
    if px-scalar-error not = spaces
        move px-scalar-error to px-sch-error
        exit paragraph
    end-if
    perform varying child-index from 1 by 1
        until child-index > px-scalar-count
        if px-sch-error-count >= 64
            move "SCHEMA_CAPACITY" to px-sch-error
            exit paragraph
        end-if
        add 1 to px-sch-error-count
        move spaces to px-sch-path(px-sch-error-count)
        move spaces to px-sch-message(px-sch-error-count)
        move px-scalar-error-path(child-index)
            to px-sch-path(px-sch-error-count)
        move px-scalar-error-message(child-index)
            to px-sch-message(px-sch-error-count)
    end-perform.
validate-object.
    if px-json-kind(1) not = "O"
        move "expected object" to message-text
        perform add-error
        exit paragraph
    end-if
    perform varying child-index from 1 by 1
        until child-index > required-count
        move required-names(child-index) to search-name
        move required-name-lengths(child-index) to search-name-length
        move 1 to node-index
        perform find-member
        if found-node = 0
            move "required field missing" to message-text
            move px-visit-path(1:px-visit-path-length) to old-path
            move px-visit-path-length to old-path-length
            if old-path-length + 1 + required-name-lengths(child-index) > 256
                move "SCHEMA_CAPACITY" to px-sch-error
                exit paragraph
            end-if
            move spaces to px-visit-path
            string old-path(1:old-path-length) delimited by size
                "." delimited by size
                required-names(child-index)(
                1:required-name-lengths(child-index))
                delimited by size into px-visit-path
            end-string
            compute px-visit-path-length = old-path-length + 1
                + required-name-lengths(child-index)
            perform add-error
            move old-path(1:old-path-length) to px-visit-path
            move old-path-length to px-visit-path-length
        end-if
    end-perform
    perform varying child-index from 1 by 1
        until child-index > property-count
        move property-names(child-index) to search-name
        move property-name-lengths(child-index) to search-name-length
        move 1 to node-index
        perform find-member
        if found-node > 0
            move found-node to node-index
            perform slice-node
            if px-json-error not = spaces
                move px-json-error to px-sch-error
                exit paragraph
            end-if
            move gen-output(1:gen-length) to data-output
            move gen-length to data-length
            move property-schemas(child-index) to child-schema
            move property-schema-lengths(child-index) to child-schema-length
            move data-output to child-data
            move data-length to child-data-length
            move px-visit-path(1:px-visit-path-length) to old-path
            move px-visit-path-length to old-path-length
            if old-path-length + 1 + property-name-lengths(child-index) > 256
                move "SCHEMA_CAPACITY" to px-sch-error
                exit paragraph
            end-if
            move spaces to child-path
            string old-path(1:old-path-length) delimited by size
                "." delimited by size
                property-names(child-index)(
                1:property-name-lengths(child-index))
                delimited by size into child-path
            end-string
            compute child-path-length = old-path-length + 1
                + property-name-lengths(child-index)
            call "praxo-schema-visit" using child-request px-schema-result
            if px-sch-error not = spaces exit paragraph end-if
        end-if
    end-perform.
validate-array.
    if px-json-kind(1) not = "A"
        move "expected array" to message-text
        perform add-error
        exit paragraph
    end-if
    if items-present = 0 exit paragraph end-if
    move 0 to child-index
    perform varying node-index from 2 by 1
        until node-index > px-json-count
        if px-json-parent(node-index) = 1
            add 1 to child-index
            perform slice-node
            if px-json-error not = spaces
                move px-json-error to px-sch-error
                exit paragraph
            end-if
            move gen-output(1:gen-length) to data-output
            move gen-length to data-length
            move items-schema to child-schema
            move items-schema-length to child-schema-length
            move data-output to child-data
            move data-length to child-data-length
            compute index-edited = child-index - 1
            move px-visit-path(1:px-visit-path-length) to old-path
            move px-visit-path-length to old-path-length
            if old-path-length + 2 + function length(
                function trim(index-edited)) > 256
                move "SCHEMA_CAPACITY" to px-sch-error
                exit paragraph
            end-if
            move spaces to child-path
            string old-path(1:old-path-length) delimited by size
                "[" delimited by size
                function trim(index-edited) delimited by size
                "]" delimited by size into child-path
            end-string
            compute child-path-length = old-path-length + 2
                + function length(function trim(index-edited))
            call "praxo-schema-visit" using child-request px-schema-result
            if px-sch-error not = spaces exit paragraph end-if
        end-if
    end-perform.
find-member.
    move 0 to found-node
    compute find-index = node-index
    perform until find-index >= px-json-count - 1
        add 1 to find-index
        if px-json-parent(find-index) = node-index
            and px-json-kind(find-index) = "K"
            and px-json-value-length(find-index) = search-name-length
            and px-json-value(find-index)(1:search-name-length)
                = search-name(1:search-name-length)
            compute found-node = find-index + 1
        end-if
    end-perform.
slice-node.
    move current-source to px-slice-source
    move current-source-length to px-slice-source-length
    compute px-slice-start = px-json-start(node-index)
    compute px-slice-size = px-json-size(node-index)
    call "praxo-json-slice" using px-slice-request px-slice-result
    if px-slice-error not = spaces
        move px-slice-error to px-json-error
        move px-slice-error to px-sch-error
    else
        if px-slice-output-length > 16384
            move "JSON_CAPACITY" to px-json-error
            move "JSON_CAPACITY" to px-sch-error
        else
            move px-slice-output(1:px-slice-output-length) to gen-output
            move px-slice-output-length to gen-length
            move spaces to px-json-error
        end-if
    end-if.
add-error.
    if px-sch-error-count >= 64
        move "SCHEMA_CAPACITY" to px-sch-error
        exit paragraph
    end-if
    add 1 to px-sch-error-count
    move spaces to px-sch-path(px-sch-error-count)
    move spaces to px-sch-message(px-sch-error-count)
    move px-visit-path(1:px-visit-path-length)
        to px-sch-path(px-sch-error-count)
    move message-text to px-sch-message(px-sch-error-count).
end program praxo-schema-visit.
