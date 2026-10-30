       >>source format free
identification division.
program-id. registry-agent-tests.
data division.
working-storage section.
copy "inputs.cpy".
copy "registry-consumer.cpy".
copy "registry.cpy".
copy "registry-state.cpy" replacing ==px-registry-state== by ==registry-a==.
copy "registry-state.cpy" replacing ==px-registry-state== by ==registry-b==.
01 failures binary-long value 0.
procedure division.
    initialize registry-a registry-b px-registry-request
    move "register" to px-reg-op
    move "echo" to px-reg-name
    move 4 to px-reg-name-length
    move "registry-echo-a" to px-reg-program
    move 15 to px-reg-program-length
    call "praxo-registry-scoped" using registry-a
        px-registry-request px-registry-result
    move "registry-echo-b" to px-reg-program
    call "praxo-registry-scoped" using registry-b
        px-registry-request px-registry-result

    move low-values to px-user-data
    set registry-pointer to address of registry-a
    perform run-agent
    if px-result-error not = spaces or px-result-output not = "A"
        or consumer-tool-count not = 1
        perform fail-case
    end-if
    set registry-pointer to address of registry-b
    perform run-agent
    if px-result-error not = spaces or px-result-output not = "B"
        or consumer-tool-count not = 1
        perform fail-case
    end-if
    move 1 to consumer-deny
    perform run-agent
    if px-result-error not = "POLICY_ERROR" or consumer-tool-count not = 0
        perform fail-case
    end-if
    move 0 to consumer-deny
    move "clear" to px-reg-op
    call "praxo-registry-scoped" using registry-b
        px-registry-request px-registry-result
    perform run-agent
    if px-result-error not = "TOOL_NOT_FOUND" or consumer-tool-count not = 0
        perform fail-case
    end-if
    move "register" to px-reg-op
    move "echo" to px-reg-name
    move 4 to px-reg-name-length
    move spaces to px-reg-program
    move 0 to px-reg-program-length
    call "praxo-registry-scoped" using registry-b
        px-registry-request px-registry-result
    perform run-agent
    if px-result-error not = "TOOL_NOT_FOUND" or consumer-tool-count not = 0
        perform fail-case
    end-if
    set registry-pointer to address of registry-a
    perform run-agent
    if px-result-error not = spaces or px-result-output not = "A"
        or consumer-tool-count not = 1
        perform fail-case
    end-if
    if failures = 0
        display "PASS: registry agent discovery, dispatch, denial, isolation"
    else
        move 1 to return-code
    end-if
    goback.
run-agent.
    initialize px-options px-session px-prompt px-result
    move 0 to consumer-model-count consumer-tool-count
    move "registry-model" to px-model-program
    move "registry-dispatch" to px-tool-program
    move "registry-policy" to px-policy-program
    move 3 to px-max-steps
    move "echo" to px-prompt-text
    move 4 to px-prompt-length
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data.
fail-case.
    add 1 to failures
    display "FAIL: registry agent error=" px-result-error
        " output=" px-result-output.
end program registry-agent-tests.

identification division.
program-id. registry-model.
data division.
local-storage section.
copy "registry.cpy".
linkage section.
copy "api.cpy".
copy "registry-consumer.cpy".
copy "registry-state.cpy".
procedure division using px-session px-response px-user-data px-status.
    add 1 to consumer-model-count
    if consumer-model-count = 1
        set address of px-registry-state to registry-pointer
        move "list" to px-reg-op
        call "praxo-registry-scoped" using px-registry-state
            px-registry-request px-registry-result
        if px-reg-error not = spaces
            move px-reg-error to px-status
            goback
        end-if
        move 1 to px-call-count
        move "echo" to px-call-name(1)
        if px-reg-count > 0
            move px-reg-entry-name(1) to px-call-name(1)
        end-if
        move "registry-call" to px-call-id(1)
        move "{}" to px-call-input(1)
        move 2 to px-call-input-length(1)
    else
        move px-content(px-message-count) to px-answer
        move px-content-length(px-message-count) to px-answer-length
    end-if
    goback.
end program registry-model.

identification division.
program-id. registry-dispatch.
data division.
local-storage section.
copy "registry.cpy".
linkage section.
copy "api.cpy".
copy "registry-consumer.cpy".
copy "registry-state.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    set address of px-registry-state to registry-pointer
    move "get" to px-reg-op
    move px-tool-name to px-reg-name
    compute px-reg-name-length = function length(function trim(px-tool-name))
    call "praxo-registry-scoped" using px-registry-state
        px-registry-request px-registry-result
    if px-reg-error not = spaces
        move px-reg-error to px-status
        goback
    end-if
    if px-reg-entry-program(1) = spaces
        move "TOOL_NOT_FOUND" to px-status
        goback
    end-if
    call px-reg-entry-program(1) using px-call px-tool-result
        px-user-data px-status
        on exception move "TOOL_NOT_FOUND" to px-status
    end-call
    goback.
end program registry-dispatch.

identification division.
program-id. registry-policy.
data division.
linkage section.
copy "api.cpy".
copy "registry-consumer.cpy".
procedure division using px-action px-user-data px-status.
    if consumer-deny = 1 and px-action-kind = "tool.invoke"
        move "DENIED" to px-status
    end-if
    goback.
end program registry-policy.

identification division.
program-id. registry-echo-a.
data division.
linkage section.
copy "api.cpy".
copy "registry-consumer.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    add 1 to consumer-tool-count
    move "A" to px-tool-output
    move 1 to px-tool-output-length
    goback.
end program registry-echo-a.

identification division.
program-id. registry-echo-b.
data division.
linkage section.
copy "api.cpy".
copy "registry-consumer.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    add 1 to consumer-tool-count
    move "B" to px-tool-output
    move 1 to px-tool-output-length
    goback.
end program registry-echo-b.
