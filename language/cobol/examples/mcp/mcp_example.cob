       >>source format free
identification division.
program-id. mcp-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "mcp.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
01 expected-json pic x(16384).
01 expected-length binary-long.
procedure division.
    move spaces to px-mcp-options px-user-data
    move "fake-mcp-transport" to px-mcp-transport-program
    move "0.8.0" to px-mcp-client-version
    move "2024-11-05" to px-mcp-protocol-version
    move "O" to px-user-data(1:1)

    move "initialize" to px-mcp-op
    call "praxo-mcp" using px-mcp-options px-mcp-result
        px-user-data px-status
    if px-status not = spaces
        display "initialize failed: " px-status
        stop run returning 1
    end-if
    if px-mcp-protocol(1:px-mcp-protocol-length) not = "2024-11-05"
        display "unexpected protocol: " px-mcp-protocol
        stop run returning 1
    end-if

    move "list-tools" to px-mcp-op
    call "praxo-mcp" using px-mcp-options px-mcp-result
        px-user-data px-status
    if px-status not = spaces
        display "list failed: " px-status
        stop run returning 1
    end-if
    move '[{"name":"echo","description":"Echo"},{"name":"two"}]'
        to expected-json
    compute expected-length = function length(
        function trim(expected-json))
    if px-mcp-output(1:px-mcp-output-length) not =
        expected-json(1:expected-length)
        display "unexpected tools: " px-mcp-output(1:px-mcp-output-length)
        stop run returning 1
    end-if

    move "call-tool" to px-mcp-op
    move "echo" to px-mcp-tool-name
    move 4 to px-mcp-tool-name-length
    move "{}" to px-mcp-arguments
    move 2 to px-mcp-arguments-length
    call "praxo-mcp" using px-mcp-options px-mcp-result
        px-user-data px-status
    if px-status not = spaces
        display "call failed: " px-status
        stop run returning 1
    end-if
    if px-mcp-output(1:px-mcp-output-length) not = '"ok"'
        display "unexpected call result: "
            px-mcp-output(1:px-mcp-output-length)
        stop run returning 1
    end-if

    move "S" to px-user-data(1:1)
    call "praxo-mcp" using px-mcp-options px-mcp-result
        px-user-data px-status
    if px-status not = spaces
        display "structured failed: " px-status
        stop run returning 1
    end-if
    if px-mcp-output(1:px-mcp-output-length) not = '{"ok":true}'
        display "unexpected structured result: "
            px-mcp-output(1:px-mcp-output-length)
        stop run returning 1
    end-if

    move "D" to px-user-data(1:1)
    move "list-tools" to px-mcp-op
    call "praxo-mcp" using px-mcp-options px-mcp-result
        px-user-data px-status
    if px-status not = "MCP_DUPLICATE_TOOL"
        display "expected duplicate error, got: " px-status
        stop run returning 1
    end-if

    move "R" to px-user-data(1:1)
    call "praxo-mcp" using px-mcp-options px-mcp-result
        px-user-data px-status
    if px-status not = "MCP_PAGINATION"
        display "expected pagination error, got: " px-status
        stop run returning 1
    end-if

    move "E" to px-user-data(1:1)
    move "call-tool" to px-mcp-op
    call "praxo-mcp" using px-mcp-options px-mcp-result
        px-user-data px-status
    if px-status not = "MCP_TOOL_ERROR"
        display "expected tool error, got: " px-status
        stop run returning 1
    end-if
    display "MCP tests passed"
    stop run.
end program mcp-tests.

identification division.
program-id. fake-mcp-transport recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 fake-json pic x(8192).
01 fake-mode pic x.
01 cursor-hits binary-long.
linkage section.
copy "mcp-call.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-mcp-call px-user-data px-status.
    move spaces to px-status
    move px-user-data(1:1) to fake-mode
    evaluate px-mcp-method
        when "initialize"
            move '{"protocolVersion":"2024-11-05","serverInfo":{"name":"fake"}}'
                to fake-json
        when "tools/list"
            if fake-mode = "D"
                move '{"tools":[{"name":"echo"},{"name":"echo"}]}'
                    to fake-json
            else
                if fake-mode = "R"
                    move '{"tools":[],"nextCursor":"c1"}' to fake-json
                else
                    move 0 to cursor-hits
                    if px-mcp-params-length > 0
                        inspect px-mcp-params(1:px-mcp-params-length)
                            tallying cursor-hits for all '"cursor"'
                    end-if
                    if cursor-hits > 0
                        move '{"tools":[{"name":"two"}]}' to fake-json
                    else
                        move '{"tools":[{"name":"echo","description":"Echo"}],"nextCursor":"c1"}'
                            to fake-json
                    end-if
                end-if
            end-if
        when "tools/call"
            if fake-mode = "E"
                move '{"isError":true}' to fake-json
            else
                if fake-mode = "S"
                    move '{"structuredContent":{"ok":true}}' to fake-json
                else
                    move '{"content":[{"type":"text","text":"ok"}]}'
                        to fake-json
                end-if
            end-if
    end-evaluate
    move fake-json to px-mcp-response
    compute px-mcp-response-length = function length(
        function trim(fake-json))
    goback.
end program fake-mcp-transport.
