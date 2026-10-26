       >>source format free
identification division.
program-id. praxo-plugin recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
copy "json.cpy".
01 search-name pic x(64).
01 search-name-length binary-long.
01 node-index binary-long.
01 find-index binary-long.
01 found-node binary-long.
01 entry-node binary-long.
01 entry-type pic x(32).
01 entry-type-length binary-long.
01 kind-value pic x(64).
01 kind-length binary-long.
01 isolation-value pic x(32).
01 isolation-length binary-long.
01 text-value pic x(32768).
01 text-length binary-long.
01 label-start binary-long.
01 label-end binary-long.
01 check-index binary-long.
01 known-kinds.
   05 known-kind-value occurs 5 times pic x(32).
01 top-key-values occurs 13 times pic x(16).
01 entry-key-values occurs 6 times pic x(16).
01 capability-values occurs 32 times pic x(2048).
01 capability-lengths occurs 32 times binary-long.
01 capability-count binary-long.
01 duplicate-capability pic 9.
01 valid-manifest pic 9.
linkage section.
copy "plugin.cpy".
procedure division using px-plugin-request px-plugin-result.
    initialize px-plugin-result
    move 0 to valid-manifest
    if px-plug-length < 1 or > 32768
        move "plugin: manifest is empty" to px-plug-error
        goback
    end-if
    move px-plug-raw(1:px-plug-length) to px-json-text
    move px-plug-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move "plugin: manifest is invalid JSON" to px-plug-error
        goback
    end-if
    if px-json-count < 1 or px-json-kind(1) not = "O"
        move "plugin: manifest must be an object" to px-plug-error
        goback
    end-if
    perform check-top-level
    if valid-manifest = 0 goback end-if
    move "schemaVersion" to search-name
    move 13 to search-name-length
    move 1 to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "N"
        move "plugin: manifest: schemaVersion must be 1"
            to px-plug-error
        goback
    end-if
    if function numval(px-json-value(found-node)(
        1:px-json-value-length(found-node))) not = 1
        move "plugin: manifest: schemaVersion must be 1"
            to px-plug-error
        goback
    end-if
    move "id" to search-name
    move 2 to search-name-length
    move 1 to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "S"
        move "plugin: manifest: id is required" to px-plug-error
        goback
    end-if
    move px-json-value(found-node) to text-value
    move px-json-value-length(found-node) to text-length
    perform validate-id
    if valid-manifest = 0 goback end-if
    move text-value(1:text-length) to px-plug-id
    move text-length to px-plug-id-length
    move "version" to search-name
    move 7 to search-name-length
    move 1 to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "S"
        move "plugin: manifest: version is required" to px-plug-error
        goback
    end-if
    move px-json-value(found-node) to text-value
    move px-json-value-length(found-node) to text-length
    perform validate-semver
    if valid-manifest = 0 goback end-if
    move "kind" to search-name
    move 4 to search-name-length
    move 1 to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "S"
        move "plugin: manifest: kind is required" to px-plug-error
        goback
    end-if
    move px-json-value(found-node) to kind-value
    move px-json-value-length(found-node) to kind-length
    perform known-kind
    if valid-manifest = 0
        move "plugin: manifest: kind is not a known contract"
            to px-plug-error
        goback
    end-if
    move kind-value(1:kind-length) to px-plug-kind
    move kind-length to px-plug-kind-length
    move "protocol" to search-name
    move 8 to search-name-length
    move 1 to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "S"
        move "plugin: manifest: protocol must be jsonrpc-2"
            to px-plug-error
        goback
    end-if
    if px-json-value-length(found-node) not = 9
        or px-json-value(found-node)(1:9) not = "jsonrpc-2"
        move "plugin: manifest: protocol must be jsonrpc-2"
            to px-plug-error
        goback
    end-if
    move "entrypoint" to search-name
    move 10 to search-name-length
    move 1 to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "O"
        move "plugin: manifest: entrypoint must be an object"
            to px-plug-error
        goback
    end-if
    move found-node to entry-node
    perform check-entry-keys
    if valid-manifest = 0 goback end-if
    move "type" to search-name
    move 4 to search-name-length
    move entry-node to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "S"
        move "plugin: manifest: entrypoint type is required"
            to px-plug-error
        goback
    end-if
    move px-json-value(found-node) to entry-type
    move px-json-value-length(found-node) to entry-type-length
    perform check-entry-required
    if valid-manifest = 0 goback end-if
    move "isolation" to search-name
    move 9 to search-name-length
    move 1 to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "S"
        move "plugin: manifest: isolation must match entrypoint"
            to px-plug-error
        goback
    end-if
    move px-json-value(found-node) to isolation-value
    move px-json-value-length(found-node) to isolation-length
    if isolation-length not = entry-type-length
        or isolation-value(1:isolation-length)
            not = entry-type(1:entry-type-length)
        move "plugin: manifest: isolation must match entrypoint"
            to px-plug-error
        goback
    end-if
    move "capabilities" to search-name
    move 12 to search-name-length
    move 1 to node-index
    perform find-child
    if found-node > 0
        if px-json-kind(found-node) not = "A"
            move "plugin: manifest: capabilities must be an array"
                to px-plug-error
            goback
        end-if
        move 0 to capability-count
        compute check-index = found-node
        perform until check-index >= px-json-count
            add 1 to check-index
            if px-json-parent(check-index) = found-node
                if px-json-kind(check-index) not = "S"
                    or px-json-value-length(check-index) < 1
                    move "plugin: manifest: capability is invalid"
                        to px-plug-error
                    goback
                end-if
                move px-json-value(check-index) to text-value
                move px-json-value-length(check-index) to text-length
                move 0 to duplicate-capability
                perform varying label-start from 1 by 1
                    until label-start > capability-count
                    if capability-lengths(label-start) = text-length
                        and capability-values(label-start)(1:text-length)
                            = text-value(1:text-length)
                        move 1 to duplicate-capability
                    end-if
                end-perform
                if duplicate-capability = 1
                    move "plugin: manifest: duplicate capability"
                        to px-plug-error
                    goback
                end-if
                if capability-count >= 32
                    move "PLUGIN_CAPACITY" to px-plug-error
                    goback
                end-if
                add 1 to capability-count
                move text-value to capability-values(capability-count)
                move text-length to capability-lengths(capability-count)
            end-if
        end-perform
    end-if
    move 1 to valid-manifest
    move 1 to px-plug-valid
    goback.
check-top-level.
    move 1 to valid-manifest
    move "id" to top-key-values(1)
    move "kind" to top-key-values(2)
    move "version" to top-key-values(3)
    move "sbom" to top-key-values(4)
    move "health" to top-key-values(5)
    move "limits" to top-key-values(6)
    move "protocol" to top-key-values(7)
    move "signature" to top-key-values(8)
    move "isolation" to top-key-values(9)
    move "entrypoint" to top-key-values(10)
    move "permissions" to top-key-values(11)
    move "capabilities" to top-key-values(12)
    move "schemaVersion" to top-key-values(13)
    compute check-index = 1
    perform until check-index >= px-json-count
        add 1 to check-index
        if px-json-parent(check-index) = 1
            and px-json-kind(check-index) = "K"
            move 0 to label-end
            perform varying label-start from 1 by 1
                until label-start > 13
                compute text-length = function length(function trim(
                    top-key-values(label-start) trailing))
                if text-length = px-json-value-length(check-index)
                    and top-key-values(label-start)(1:text-length)
                        = px-json-value(check-index)(1:text-length)
                    move 1 to label-end
                end-if
            end-perform
            if label-end = 0
                move "plugin: manifest: unknown field" to px-plug-error
                move 0 to valid-manifest
                exit paragraph
            end-if
        end-if
    end-perform.
check-entry-keys.
    move 1 to valid-manifest
    move "type" to entry-key-values(1)
    move "args" to entry-key-values(2)
    move "dir" to entry-key-values(3)
    move "image" to entry-key-values(4)
    move "module" to entry-key-values(5)
    move "command" to entry-key-values(6)
    compute check-index = entry-node
    perform until check-index >= px-json-count
        add 1 to check-index
        if px-json-parent(check-index) = entry-node
            and px-json-kind(check-index) = "K"
            move 0 to label-end
            perform varying label-start from 1 by 1
                until label-start > 6
                compute text-length = function length(function trim(
                    entry-key-values(label-start) trailing))
                if text-length = px-json-value-length(check-index)
                    and entry-key-values(label-start)(1:text-length)
                        = px-json-value(check-index)(1:text-length)
                    move 1 to label-end
                end-if
            end-perform
            if label-end = 0
                move "plugin: manifest: unknown entrypoint field"
                    to px-plug-error
                move 0 to valid-manifest
                exit paragraph
            end-if
        end-if
    end-perform.
check-entry-required.
    move 0 to found-node
    if entry-type-length = 7 and entry-type(1:7) = "process"
        move "command" to search-name
        move 7 to search-name-length
    else
        if entry-type-length = 4 and entry-type(1:4) = "wasm"
            move "module" to search-name
            move 6 to search-name-length
        else
            if entry-type-length = 9
                and entry-type(1:9) = "container"
                move "image" to search-name
                move 5 to search-name-length
            else
                move "plugin: manifest: unknown entrypoint type"
                    to px-plug-error
                move 0 to valid-manifest
                exit paragraph
            end-if
        end-if
    end-if
    move entry-node to node-index
    perform find-child
    if found-node = 0 or px-json-kind(found-node) not = "S"
        or px-json-value-length(found-node) < 1
        move "plugin: manifest: entrypoint target is required"
            to px-plug-error
        move 0 to valid-manifest
    end-if.
find-child.
    compute find-index = node-index
    perform until find-index >= px-json-count
        add 1 to find-index
        if px-json-parent(find-index) = node-index
            and px-json-value-length(find-index) = search-name-length
            and px-json-value(find-index)(1:search-name-length)
                = search-name(1:search-name-length)
            compute found-node = find-index + 1
        end-if
    end-perform.
validate-id.
    move 1 to valid-manifest
    if text-length < 3
        move 0 to valid-manifest
        exit paragraph
    end-if
    move 1 to label-start    perform varying check-index from 1 by 1
        until check-index > text-length
        if text-value(check-index:1) = "."
            compute label-end = check-index - 1
            perform check-label
            if valid-manifest = 0 exit paragraph end-if
            compute label-start = check-index + 1
        else
            perform valid-id-char
            if valid-manifest = 0
                exit paragraph
            end-if
        end-if
    end-perform
    compute label-end = text-length
    perform check-label
    if label-start = 1 move 0 to valid-manifest end-if.
check-label.
    if label-end < label-start
        move 0 to valid-manifest
        exit paragraph
    end-if
    if text-value(label-start:1) = "-"
        or text-value(label-end:1) = "-"
        move 0 to valid-manifest
    end-if.
valid-id-char.
    if text-value(check-index:1) >= "a"
        and <= "z"
        exit paragraph
    end-if
    if text-value(check-index:1) >= "0"
        and <= "9"
        exit paragraph
    end-if
    if text-value(check-index:1) = "-"
        exit paragraph
    end-if
    move 0 to valid-manifest.
validate-semver.
    move 1 to valid-manifest
    if text-length < 5
        move 0 to valid-manifest
        exit paragraph
    end-if
    move 1 to check-index
    perform varying label-end from 1 by 1
        until label-end > 3
        if check-index > text-length
            move 0 to valid-manifest
            exit paragraph
        end-if
        if text-value(check-index:1) = "0"
            add 1 to check-index
            if check-index <= text-length
                if text-value(check-index:1) >= "0"
                    and <= "9"
                    move 0 to valid-manifest
                    exit paragraph
                end-if
            end-if
        else
            if text-value(check-index:1) < "1"
                or > "9"
                move 0 to valid-manifest
                exit paragraph
            end-if
            perform until check-index > text-length
                if text-value(check-index:1) < "0"
                    or > "9"
                    exit perform
                end-if
                add 1 to check-index
            end-perform
        end-if
        if label-end < 3
            if check-index <= text-length
                if text-value(check-index:1) = "."
                    add 1 to check-index
                else
                    move 0 to valid-manifest
                    exit paragraph
                end-if
            else
                move 0 to valid-manifest
                exit paragraph
            end-if
        end-if
    end-perform
    if check-index <= text-length
        if text-value(check-index:1) not = "-"
            and not = "+"
            move 0 to valid-manifest
            exit paragraph
        end-if
        add 1 to check-index
        if check-index > text-length
            move 0 to valid-manifest
            exit paragraph
        end-if
        perform until check-index > text-length
            if text-value(check-index:1) = "."
                or text-value(check-index:1) = "-"
                or text-value(check-index:1) = "+"
                continue
            end-if
            if text-value(check-index:1) >= "0"
                and <= "9"
                continue
            end-if
            if text-value(check-index:1) >= "a"
                and <= "z"
                continue
            end-if
            if text-value(check-index:1) >= "A"
                and <= "Z"
                continue
            end-if
            move 0 to valid-manifest
            exit paragraph
        end-perform
    end-if.
known-kind.
    move 0 to valid-manifest
    move "tool.provider.v1" to known-kind-value(1)
    move "model.provider.v1" to known-kind-value(2)
    move "policy.provider.v1" to known-kind-value(3)
    move "memory.provider.v1" to known-kind-value(4)
    move "sandbox.provider.v1" to known-kind-value(5)
    perform varying check-index from 1 by 1
        until check-index > 5
        compute label-start = function length(function trim(
            known-kind-value(check-index) trailing))
        if kind-length = label-start
            and kind-value(1:kind-length)
                = known-kind-value(check-index)(1:kind-length)
            move 1 to valid-manifest
            exit paragraph
        end-if
    end-perform.
end program praxo-plugin.

