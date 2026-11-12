       >>source format free
identification division.
program-id. praxo-mcp recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 ws-params pic x(8192).
01 ws-params-position binary-long.
01 ws-tools pic x(16384).
01 ws-tools-position binary-long.
01 ws-source pic x(4096).
01 ws-source-length binary-long.
01 ws-literal pic x(4096).
01 ws-piece pic x(16384).
01 ws-piece-length binary-long.
01 ws-parent binary-long.
01 ws-key pic x(64).
01 ws-found binary-long.
01 ws-value-node binary-long.
01 ws-loop binary-long.
01 ws-find binary-long.
01 ws-check binary-long.
01 ws-node binary-long.
01 ws-tools-node binary-long.
01 ws-start binary-long.
01 ws-size binary-long.
01 ws-end binary-long.
01 ws-raw pic x(8192).
01 ws-raw-length binary-long.
01 ws-cursor pic x(1024).
01 ws-cursor-length binary-long.
01 ws-name-count binary-long.
01 ws-name-table.
   05 ws-name-entry occurs 64 times pic x(64).
01 ws-cursor-count binary-long.
01 ws-cursor-table.
   05 ws-cursor-entry occurs 64 times pic x(1024).
01 ws-text-count binary-long.
01 ws-single pic x(8192).
01 ws-single-length binary-long.
01 ws-array pic x(16384).
01 ws-array-position binary-long.
01 ws-array-length binary-long.
local-storage section.
copy "mcp-call.cpy".
copy "json.cpy".
linkage section.
copy "mcp.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-mcp-options px-mcp-result
    px-user-data px-status.
    initialize px-mcp-result
    move spaces to px-status
    evaluate px-mcp-op
        when "initialize" perform do-initialize
        when "list-tools" perform do-list-tools
        when "call-tool" perform do-call-tool
        when "close" continue
        when other move "MCP_PROTOCOL" to px-status
    end-evaluate
    goback.
do-initialize.
    perform reset-params
    move '{"protocolVersion":' to ws-literal
    perform append-literal
    if px-mcp-protocol-version = spaces
        move "2024-11-05" to ws-source
        move 10 to ws-source-length
    else
        move function trim(px-mcp-protocol-version) to ws-source
        compute ws-source-length = function length(
            function trim(px-mcp-protocol-version))
    end-if
    perform quote-source
    move ',"capabilities":{},"clientInfo":{"name":"praxo-core","version":'
        to ws-literal
    perform append-literal
    if px-mcp-client-version = spaces
        move "0.8.0" to ws-source
        move 5 to ws-source-length
    else
        move function trim(px-mcp-client-version) to ws-source
        compute ws-source-length = function length(
            function trim(px-mcp-client-version))
    end-if
    perform quote-source
    move "}}" to ws-literal
    perform append-literal
    move "initialize" to px-mcp-method
    perform call-transport
    if px-status not = spaces goback end-if
    perform parse-response
    if px-status not = spaces goback end-if
    if px-json-count < 1 or px-json-kind(1) not = 'O'
        move "MCP_PROTOCOL" to px-status
        goback
    end-if
    move 1 to ws-parent
    move "protocolVersion" to ws-key
    perform find-field
    if ws-found = 0
        or px-json-kind(ws-value-node) not = 'S'
        or px-json-value-length(ws-value-node) = 0
        move "MCP_HANDSHAKE" to px-status
        goback
    end-if
    move px-json-value(ws-value-node) to px-mcp-protocol
    move px-json-value-length(ws-value-node) to px-mcp-protocol-length
    move 1 to ws-parent
    move "serverInfo" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'O'
        move ws-value-node to ws-node
        perform raw-node
        move ws-raw to px-mcp-server-info
        move ws-raw-length to px-mcp-server-info-length
    else
        move "{}" to px-mcp-server-info
        move 2 to px-mcp-server-info-length
    end-if.
do-list-tools.
    move 0 to ws-name-count ws-cursor-count
    move spaces to ws-cursor
    move 0 to ws-cursor-length
    move 2 to ws-tools-position
    move "[" to ws-tools
    perform until px-status not = spaces
        perform reset-params
        if ws-cursor-length = 0
            move "{}" to ws-literal
            perform append-literal
        else
            move '{"cursor":' to ws-literal
            perform append-literal
            move ws-cursor to ws-source
            move ws-cursor-length to ws-source-length
            perform quote-source
            move "}" to ws-literal
            perform append-literal
        end-if
        move "tools/list" to px-mcp-method
        perform call-transport
        if px-status not = spaces exit perform end-if
        perform parse-response
        if px-status not = spaces exit perform end-if
        if px-json-count < 1 or px-json-kind(1) not = 'O'
            move "MCP_PROTOCOL" to px-status
            exit perform
        end-if
        move 1 to ws-parent
        move "tools" to ws-key
        perform find-field
        if ws-found = 0 or px-json-kind(ws-value-node) not = 'A'
            move "MCP_PROTOCOL" to px-status
            exit perform
        end-if
        move ws-value-node to ws-tools-node
        perform varying ws-loop from 1 by 1
            until ws-loop > px-json-count or px-status not = spaces
            if px-json-parent(ws-loop) not = ws-tools-node exit perform cycle end-if
            if px-json-kind(ws-loop) not = 'O'
                move "MCP_PROTOCOL" to px-status
                exit perform
            end-if
            move ws-loop to ws-parent
            move "name" to ws-key
            perform find-field
            if ws-found = 0
                or px-json-kind(ws-value-node) not = 'S'
                or px-json-value-length(ws-value-node) = 0
                move "MCP_PROTOCOL" to px-status
                exit perform
            end-if
            perform check-name
            if px-status not = spaces exit perform end-if
            perform add-name
            move ws-loop to ws-node
            perform raw-node
            if ws-raw-length = 0
                move "MCP_PROTOCOL" to px-status
                exit perform
            end-if
            if ws-tools-position > 2
                move "," to ws-tools(ws-tools-position:1)
                add 1 to ws-tools-position
            end-if
            if ws-tools-position + ws-raw-length - 1 > 16384
                move "MCP_PROTOCOL" to px-status
                exit perform
            end-if
            move ws-raw(1:ws-raw-length) to
                ws-tools(ws-tools-position:ws-raw-length)
            add ws-raw-length to ws-tools-position
        end-perform
        if px-status not = spaces exit perform end-if
        move 1 to ws-parent
        move "nextCursor" to ws-key
        perform find-field
        if ws-found = 0
            move 0 to ws-cursor-length
            move spaces to ws-cursor
            exit perform
        end-if
        if px-json-kind(ws-value-node) = 'Z'
            move 0 to ws-cursor-length
            move spaces to ws-cursor
            exit perform
        end-if
        if px-json-kind(ws-value-node) not = 'S'
            move "MCP_PROTOCOL" to px-status
            exit perform
        end-if
        move px-json-value(ws-value-node) to ws-cursor
        move px-json-value-length(ws-value-node) to ws-cursor-length
        if ws-cursor-length = 0 exit perform end-if
        perform check-cursor
        if px-status not = spaces exit perform end-if
        perform add-cursor
    end-perform
    if px-status not = spaces goback end-if
    if ws-tools-position + 1 > 16384
        move "MCP_PROTOCOL" to px-status
        goback
    end-if
    move "]" to ws-tools(ws-tools-position:1)
    add 1 to ws-tools-position
    compute px-mcp-output-length = ws-tools-position - 1
    move ws-tools to px-mcp-output.
do-call-tool.
    if px-mcp-tool-name-length = 0
        move "MCP_PROTOCOL" to px-status
        goback
    end-if
    perform reset-params
    move '{"name":' to ws-literal
    perform append-literal
    move px-mcp-tool-name to ws-source
    move px-mcp-tool-name-length to ws-source-length
    perform quote-source
    move ',"arguments":' to ws-literal
    perform append-literal
    if px-mcp-arguments-length = 0
        move "{}" to ws-literal
        perform append-literal
    else
        move px-mcp-arguments-length to ws-piece-length
        move px-mcp-arguments to ws-piece
        perform append-piece
    end-if
    move "}" to ws-literal
    perform append-literal
    move "tools/call" to px-mcp-method
    perform call-transport
    if px-status not = spaces goback end-if
    perform parse-response
    if px-status not = spaces goback end-if
    if px-json-count < 1 or px-json-kind(1) not = 'O'
        move "MCP_PROTOCOL" to px-status
        goback
    end-if
    move 1 to ws-parent
    move "isError" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'T'
        move "MCP_TOOL_ERROR" to px-status
        goback
    end-if
    move 1 to ws-parent
    move "structuredContent" to ws-key
    perform find-field
    if ws-found = 1
        move ws-value-node to ws-node
        perform raw-node
        move ws-raw to px-mcp-output
        move ws-raw-length to px-mcp-output-length
        goback
    end-if
    move 0 to ws-text-count
    move spaces to ws-single
    move 0 to ws-single-length
    move "[" to ws-array
    move 1 to ws-array-position
    move 1 to ws-parent
    move "content" to ws-key
    perform find-field
    if ws-found = 1 and px-json-kind(ws-value-node) = 'A'
        move ws-value-node to ws-tools-node
        perform varying ws-loop from 1 by 1
            until ws-loop > px-json-count or px-status not = spaces
            if px-json-parent(ws-loop) not = ws-tools-node exit perform cycle end-if
            if px-json-kind(ws-loop) not = 'O' exit perform cycle end-if
            move ws-loop to ws-parent
            move "type" to ws-key
            perform find-field
            if ws-found = 0 or px-json-kind(ws-value-node) not = 'S'
                exit perform cycle
            end-if
            if function trim(px-json-value(ws-value-node)) not = "text"
                exit perform cycle
            end-if
            move ws-loop to ws-parent
            move "text" to ws-key
            perform find-field
            if ws-found = 0 or px-json-kind(ws-value-node) not = 'S'
                exit perform cycle
            end-if
            move px-json-value(ws-value-node) to px-string-value
            move px-json-value-length(ws-value-node) to px-string-length
            perform quote-value
            if px-status not = spaces exit perform end-if
            add 1 to ws-text-count
            if ws-text-count = 1
                move px-output-text to ws-single
                move px-output-length to ws-single-length
            else
                if ws-text-count = 2
                    move ws-single(1:ws-single-length) to
                        ws-array(ws-array-position:ws-single-length)
                    add ws-single-length to ws-array-position
                    move "," to ws-array(ws-array-position:1)
                    add 1 to ws-array-position
                else
                    move "," to ws-array(ws-array-position:1)
                    add 1 to ws-array-position
                end-if
                if ws-array-position + px-output-length - 1 > 16384
                    move "MCP_PROTOCOL" to px-status
                    exit perform
                end-if
                move px-output-text(1:px-output-length) to
                    ws-array(ws-array-position:px-output-length)
                add px-output-length to ws-array-position
            end-if
        end-perform
    end-if
    if px-status not = spaces goback end-if
    evaluate ws-text-count
        when 0
            move "null" to px-mcp-output
            move 4 to px-mcp-output-length
        when 1
            move ws-single to px-mcp-output
            move ws-single-length to px-mcp-output-length
        when other
            move "]" to ws-array(ws-array-position:1)
            add 1 to ws-array-position
            compute ws-array-length = ws-array-position - 1
            move ws-array to px-mcp-output
            move ws-array-length to px-mcp-output-length
    end-evaluate.
reset-params.
    move spaces to ws-params
    move 1 to ws-params-position.
append-literal.
    compute ws-piece-length = function length(function trim(ws-literal))
    if ws-piece-length > 0
        move ws-literal(1:ws-piece-length) to ws-piece
        perform append-piece
    end-if.
append-piece.
    if ws-piece-length > 0
        if ws-params-position + ws-piece-length - 1 > 8192
            move "MCP_PROTOCOL" to px-status
            exit paragraph
        end-if
        move ws-piece(1:ws-piece-length) to
            ws-params(ws-params-position:ws-piece-length)
        add ws-piece-length to ws-params-position
    end-if.
quote-source.
    move ws-source to px-string-value
    move ws-source-length to px-string-length
    perform quote-value
    if px-status not = spaces exit paragraph end-if
    move px-output-text to ws-piece
    move px-output-length to ws-piece-length
    perform append-piece.
quote-value.
    move spaces to px-json-error
    call "praxo-json-quote" using px-json-string px-json-output
        px-json-error
    if px-json-error not = spaces
        move "MCP_PROTOCOL" to px-status
    end-if.
call-transport.
    move spaces to px-status
    move spaces to px-mcp-response
    move 0 to px-mcp-response-length
    compute px-mcp-params-length = ws-params-position - 1
    move ws-params to px-mcp-params
    call px-mcp-transport-program using px-mcp-call px-user-data px-status.
parse-response.
    move spaces to px-json-error
    move px-mcp-response to px-json-text
    move px-mcp-response-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move "MCP_PROTOCOL" to px-status
    end-if.
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
check-name.
    if ws-name-count >= 64
        move "MCP_PROTOCOL" to px-status
        exit paragraph
    end-if
    perform varying ws-check from 1 by 1 until ws-check > ws-name-count
        if ws-name-entry(ws-check) = px-json-value(ws-value-node)
            move "MCP_DUPLICATE_TOOL" to px-status
            exit paragraph
        end-if
    end-perform.
add-name.
    add 1 to ws-name-count
    move px-json-value(ws-value-node) to
        ws-name-entry(ws-name-count).
check-cursor.
    if ws-cursor-count >= 64
        move "MCP_PROTOCOL" to px-status
        exit paragraph
    end-if
    perform varying ws-check from 1 by 1 until ws-check > ws-cursor-count
        if ws-cursor-entry(ws-check) = ws-cursor
            move "MCP_PAGINATION" to px-status
            exit paragraph
        end-if
    end-perform.
add-cursor.
    add 1 to ws-cursor-count
    move ws-cursor to ws-cursor-entry(ws-cursor-count).
end program praxo-mcp.
