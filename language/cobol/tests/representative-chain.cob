       >>source format free
identification division.
program-id. representative-chain-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "api.cpy".
copy "representative-chain-state.cpy".
copy "mcp.cpy".
01 failures binary-long value 0.
01 test-name pic x(64).
01 ws-hits binary-long.
procedure division.
    perform reset-chain
    perform warm-mcp
    move "parent chain" to test-name
    perform run-parent
    move "edited denial" to test-name
    perform run-denial
    if failures = 0
        display "PASS: representative chain"
        move 0 to return-code
    else
        display "FAIL: " failures " chain assertions"
        move 1 to return-code
    end-if
    goback.

reset-chain.
    initialize px-options px-session px-prompt px-result
    initialize px-user-data
    move "parent" to gv-side
    move "parent" to gv-target
    move 0 to gv-parent-calls gv-child-calls gv-tool-calls
    move 0 to gv-effect-parent gv-effect-child gv-effect-blocked
    move 0 to gv-otel-started gv-otel-tool gv-otel-completed
    move 0 to gv-harm-started gv-harm-tool gv-harm-completed
    move 0 to gv-policy-count gv-mutate
    move "chain-model" to px-model-program
    move "chain-tool" to px-tool-program
    move "chain-policy" to px-policy-program
    move "chain-sinks" to px-event-program
    move 6 to px-max-steps
    move 1 to px-require-policy
    move 1 to px-require-tool-scope
    move 2 to px-allowed-tool-count
    move "record" to px-allowed-tools(1)
    move "delegate" to px-allowed-tools(2)
    move "run representative chain" to px-prompt-text
    compute px-prompt-length = function length(
        function trim(px-prompt-text)).

warm-mcp.
    initialize px-mcp-options px-mcp-result
    move "chain-mcp-transport" to px-mcp-transport-program
    move "0.8.0" to px-mcp-client-version
    move "2024-11-05" to px-mcp-protocol-version
    move "initialize" to px-mcp-op
    call "praxo-mcp" using px-mcp-options px-mcp-result px-user-data
        px-status
    if px-status not = spaces
        add 1 to failures
        display "FAIL: mcp initialize " trim(px-status)
    end-if
    move "list-tools" to px-mcp-op
    call "praxo-mcp" using px-mcp-options px-mcp-result px-user-data
        px-status
    if px-status not = spaces or px-mcp-output-length < 1
        add 1 to failures
        display "FAIL: mcp list-tools " trim(px-status)
    end-if.

run-parent.
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error not = spaces
        perform fail-case
        exit paragraph
    end-if
    if px-result-length not = 4 or px-result-output(1:4) not = "DONE"
        perform fail-case
    end-if
    if gv-parent-calls not = 3 or gv-child-calls < 2
        perform fail-case
    end-if
    if gv-effect-parent not = 1 or gv-effect-child not = 1
        perform fail-case
    end-if
    if gv-otel-started not = 1 or gv-otel-tool not = 1
        or gv-otel-completed not = 1
        perform fail-case
    end-if
    if gv-harm-started not = 1 or gv-harm-tool not = 1
        or gv-harm-completed not = 1
        perform fail-case
    end-if.

run-denial.
    initialize px-options px-session px-prompt px-result
    move "parent" to gv-side
    move "safe" to gv-target
    move 0 to gv-parent-calls gv-child-calls gv-tool-calls
    move 0 to gv-effect-parent gv-effect-child gv-effect-blocked
    move 0 to gv-policy-count
    move 1 to gv-mutate
    move "chain-model" to px-model-program
    move "chain-tool" to px-tool-program
    move "chain-policy" to px-policy-program
    move "chain-sinks" to px-event-program
    move "chain-before-tool" to px-before-tool-program
    move 2 to px-max-steps
    move 1 to px-require-policy
    move 1 to px-require-tool-scope
    move 1 to px-allowed-tool-count
    move "record" to px-allowed-tools(1)
    move "record once" to px-prompt-text
    compute px-prompt-length = function length(
        function trim(px-prompt-text))
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error not = "POLICY_ERROR"
        perform fail-case
    end-if
    if gv-effect-blocked not = 0 or gv-tool-calls not = 0
        or gv-effect-parent not = 0
        perform fail-case
    end-if.

fail-case.
    add 1 to failures
    display "FAIL: " trim(test-name) " error=" trim(px-result-error)
        " side=" gv-side.
end program representative-chain-tests.

identification division.
program-id. chain-model recursive.
data division.
linkage section.
copy "api.cpy".
copy "representative-chain-state.cpy".
procedure division using px-session px-response px-user-data px-status.
    move spaces to px-status
    move 0 to px-call-count
    if gv-side = "child"
        add 1 to gv-child-calls
        if gv-child-calls = 1
            move spaces to px-answer
            move 0 to px-answer-length
            move 1 to px-call-count
            move "c1" to px-call-id(1)
            move "record" to px-call-name(1)
            move '{"target":"child"}' to px-call-input(1)
            compute px-call-input-length(1) = function length(
                function trim(px-call-input(1)))
        else
            move "CHILD-DONE" to px-answer
            move 10 to px-answer-length
        end-if
    else
        add 1 to gv-parent-calls
        evaluate gv-parent-calls
            when 1
                move spaces to px-answer
                move 0 to px-answer-length
                move 1 to px-call-count
                move "p1" to px-call-id(1)
                move "record" to px-call-name(1)
                if gv-target = "safe"
                    move '{"target":"safe"}' to px-call-input(1)
                else
                    move '{"target":"parent"}' to px-call-input(1)
                end-if
                compute px-call-input-length(1) = function length(
                    function trim(px-call-input(1)))
            when 2
                move spaces to px-answer
                move 0 to px-answer-length
                move 1 to px-call-count
                move "p2" to px-call-id(1)
                move "delegate" to px-call-name(1)
                move '{"task":"child"}' to px-call-input(1)
                compute px-call-input-length(1) = function length(
                    function trim(px-call-input(1)))
            when other
                move "DONE" to px-answer
                move 4 to px-answer-length
        end-evaluate
    end-if
    goback.
end program chain-model.

identification division.
program-id. chain-tool recursive.
data division.
working-storage section.
copy "mcp.cpy".
01 mcp-status pic x(64).
linkage section.
copy "api.cpy".
copy "representative-chain-state.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    move spaces to px-status
    evaluate px-tool-name
        when "record"
            perform call-record
        when "delegate"
            call "chain-delegate" using px-user-data px-status
        when other
            move "TOOL_NOT_FOUND" to px-status
    end-evaluate
    goback.
call-record.
    initialize px-mcp-options px-mcp-result
    move "call-tool" to px-mcp-op
    move "chain-mcp-transport" to px-mcp-transport-program
    move px-tool-name to px-mcp-tool-name
    compute px-mcp-tool-name-length = function length(
        function trim(px-tool-name))
    move px-tool-input to px-mcp-arguments
    move px-tool-input-length to px-mcp-arguments-length
    move spaces to mcp-status
    call "praxo-mcp" using px-mcp-options px-mcp-result px-user-data
        mcp-status
    if mcp-status not = spaces
        move mcp-status to px-status
    else
        move px-mcp-output to px-tool-output
        move px-mcp-output-length to px-tool-output-length
    end-if.
end program chain-tool.

identification division.
program-id. chain-delegate recursive.
data division.
working-storage section.
copy "representative-chain-child.cpy".
linkage section.
copy "api.cpy".
copy "representative-chain-state.cpy".
procedure division using px-user-data px-status.
    move spaces to px-status
    initialize ch-options ch-session ch-prompt ch-result
    move "chain-model" to ch-model-program
    move "chain-tool" to ch-tool-program
    move "chain-policy" to ch-policy-program
    move "chain-sinks" to ch-event-program
    move 3 to ch-max-steps
    move 1 to ch-require-policy
    move 1 to ch-require-tool-scope
    move 1 to ch-allowed-tool-count
    move "record" to ch-allowed-tools(1)
    move "record once" to ch-prompt-text
    compute ch-prompt-length = function length(
        function trim(ch-prompt-text))
    move 0 to ch-message-count
    move "child" to gv-side
    call "praxo-run" using ch-options ch-session ch-prompt ch-result
        px-user-data
    move "parent" to gv-side
    if ch-result-error not = spaces
        move ch-result-error to px-status
    end-if
    goback.
end program chain-delegate.

identification division.
program-id. chain-policy recursive.
data division.
working-storage section.
01 ws-blocked binary-long.
linkage section.
copy "api.cpy".
copy "representative-chain-state.cpy".
procedure division using px-action px-user-data px-status.
    move spaces to px-status
    if px-action-kind = "model.generate"
        goback
    end-if
    if px-action-kind not = "tool.invoke"
        goback
    end-if
    add 1 to gv-policy-count
    if gv-side = "child" and px-action-tool not = "record"
        move "DENIED" to px-status
        goback
    end-if
    if gv-side = "parent" and px-action-tool not = "record"
        and px-action-tool not = "delegate"
        move "DENIED" to px-status
        goback
    end-if
    if px-action-tool = "record"
        move 0 to ws-blocked
        inspect px-action-input tallying ws-blocked
            for all '"blocked"'
        if ws-blocked > 0
            move "DENIED" to px-status
        end-if
    end-if
    goback.
end program chain-policy.

identification division.
program-id. chain-before-tool recursive.
data division.
linkage section.
copy "api.cpy".
copy "representative-chain-state.cpy".
procedure division using px-call px-user-data px-status.
    move spaces to px-status
    if gv-mutate = 1
        move '{"target":"blocked"}' to px-tool-input
        move 20 to px-tool-input-length
    end-if
    goback.
end program chain-before-tool.

identification division.
program-id. chain-sinks recursive.
data division.
working-storage section.
copy "otel.cpy".
copy "otel-event.cpy".
copy "harmovela.cpy".
01 px-harmovela-event.
   05 px-harmovela-event-kind pic x(32).
   05 px-harmovela-event-tool pic x(64).
linkage section.
copy "api.cpy".
copy "representative-chain-state.cpy".
procedure division using px-event px-user-data px-status.
    move spaces to px-status
    initialize px-otel-options px-otel-result px-otel-event
    move "chain-otel-transport" to px-otel-transport-program
    move "http://otel.test/v1/traces" to px-otel-endpoint
    move "praxo-chain" to px-otel-service-name
    move px-event-kind to px-otel-event-type
    move "chain-parent" to px-otel-event-session-id
    move "chain-run" to px-otel-event-run-id
    move 1794294000000000000 to px-otel-event-nanos
    move 0 to px-otel-allowed-key-count
    call "praxo-otel" using px-otel-options px-otel-result
        px-otel-event px-user-data px-status
    move spaces to px-status
    initialize px-harmovela-options px-harmovela-result
    move "chain-harmovela-transport" to
        px-harmovela-transport-program
    move "http://harmovela.test/aep/api/" to px-harmovela-base-url
    move "praxo-chain" to px-harmovela-source
    move "0.2" to px-harmovela-spec
    move "chain-run" to px-harmovela-id-prefix
    move "1794294000000000000" to px-harmovela-id-suffix
    move "2026-11-17T00:00:00.000000000Z"
        to px-harmovela-created-at
    move px-event-kind to px-harmovela-event-kind
    move px-event-tool to px-harmovela-event-tool
    call "praxo-harmovela" using px-harmovela-options
        px-harmovela-result px-harmovela-event px-user-data px-status
    move spaces to px-status
    goback.
end program chain-sinks.

identification division.
program-id. chain-mcp-transport recursive.
data division.
working-storage section.
01 fake-json pic x(8192).
01 ws-hits binary-long.
linkage section.
copy "mcp-call.cpy".
01 px-user-data pic x(4096).
copy "representative-chain-state.cpy".
01 px-status pic x(64).
procedure division using px-mcp-call px-user-data px-status.
    move spaces to px-status
    evaluate px-mcp-method
        when "initialize"
            move '{"protocolVersion":"2024-11-05","serverInfo":{"name":"chain"}}'
                to fake-json
        when "tools/list"
            move '{"tools":[{"name":"record","description":"Record a target"}]}'
                to fake-json
        when "tools/call"
            add 1 to gv-tool-calls
            move 0 to ws-hits
            inspect px-mcp-params tallying ws-hits
                for all '"target":"parent"'
            if ws-hits > 0 add 1 to gv-effect-parent end-if
            move 0 to ws-hits
            inspect px-mcp-params tallying ws-hits
                for all '"target":"child"'
            if ws-hits > 0 add 1 to gv-effect-child end-if
            move 0 to ws-hits
            inspect px-mcp-params tallying ws-hits
                for all '"target":"blocked"'
            if ws-hits > 0 add 1 to gv-effect-blocked end-if
            move '{"content":[{"type":"text","text":"recorded"}]}'
                to fake-json
        when other
            move '{}' to fake-json
    end-evaluate
    move fake-json to px-mcp-response
    compute px-mcp-response-length = function length(
        function trim(fake-json))
    goback.
end program chain-mcp-transport.

identification division.
program-id. chain-otel-transport recursive.
data division.
working-storage section.
01 ws-hits binary-long.
linkage section.
copy "otel-call.cpy".
01 px-user-data pic x(4096).
copy "representative-chain-state.cpy".
01 px-status pic x(64).
procedure division using px-otel-call px-user-data px-status.
    move spaces to px-status
    move 0 to ws-hits
    inspect px-otel-body tallying ws-hits
        for all "praxo.run.started"
    if ws-hits > 0 move 1 to gv-otel-started end-if
    move 0 to ws-hits
    inspect px-otel-body tallying ws-hits
        for all "praxo.tool.call"
    if ws-hits > 0 move 1 to gv-otel-tool end-if
    move 0 to ws-hits
    inspect px-otel-body tallying ws-hits
        for all "praxo.run.completed"
    if ws-hits > 0 move 1 to gv-otel-completed end-if
    move 200 to px-otel-status-code
    move "ok" to px-otel-response
    move 2 to px-otel-response-length
    goback.
end program chain-otel-transport.

identification division.
program-id. chain-harmovela-transport recursive.
data division.
working-storage section.
01 ws-hits binary-long.
linkage section.
copy "harmovela-call.cpy".
01 px-user-data pic x(4096).
copy "representative-chain-state.cpy".
01 px-status pic x(64).
procedure division using px-harmovela-call px-user-data px-status.
    move spaces to px-status
    move 0 to ws-hits
    inspect px-harmovela-body tallying ws-hits
        for all '"type":"run.started"'
    if ws-hits > 0 move 1 to gv-harm-started end-if
    move 0 to ws-hits
    inspect px-harmovela-body tallying ws-hits
        for all '"type":"tool.call"'
    if ws-hits > 0 move 1 to gv-harm-tool end-if
    move 0 to ws-hits
    inspect px-harmovela-body tallying ws-hits
        for all '"type":"run.completed"'
    if ws-hits > 0 move 1 to gv-harm-completed end-if
    move 204 to px-harmovela-status-code
    goback.
end program chain-harmovela-transport.
