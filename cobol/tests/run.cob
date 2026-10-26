       >>source format free
identification division.
program-id. core-tests.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "api.cpy".
copy "state.cpy".
01 saved-session.
   copy "history.cpy".
01 failures binary-long value 0.
01 test-name pic x(64).
procedure division.
    perform reset-case
    move "direct answer" to test-name
    perform run-agent
    if px-result-output not = "hello" or px-result-length not = 5
        or px-result-steps not = 1 or event-count not = 2
        or event-types(1) not = "run.started"
        or event-types(2) not = "run.completed"
        perform fail-case
    end-if

    perform reset-case
    move "tool then answer with history" to test-name
    move 1 to test-mode
    perform run-agent
    if px-result-output not = "hello" or px-result-steps not = 2
        or tool-count not = 1 or history-valid not = 1
        or event-count not = 3 or event-types(2) not = "tool.call"
        perform fail-case
    end-if

    perform reset-case
    move "step budget" to test-name
    move 2 to test-mode
    move 1 to px-max-steps
    perform run-agent
    if px-result-error not = "AGENT_MAX_STEPS"
        or model-count not = 1 or tool-count not = 1
        or event-types(3) not = "run.failed"
        perform fail-case
    end-if

    perform reset-case
    move "token budget" to test-name
    move 3 to test-mode
    move 5 to px-max-tokens
    perform run-agent
    if px-result-error not = "AGENT_MAX_TOKENS"
        or px-result-length not = 0 or tool-count not = 0
        or event-types(2) not = "run.failed"
        perform fail-case
    end-if

    perform reset-case
    move "model policy denial" to test-name
    move 4 to test-mode
    perform run-agent
    if px-result-error not = "POLICY_ERROR" or model-count not = 0
        or event-types(2) not = "run.failed"
        perform fail-case
    end-if

    perform reset-case
    move "tool policy denial" to test-name
    move 5 to test-mode
    perform run-agent
    if px-result-error not = "POLICY_ERROR" or tool-count not = 0
        or event-count not = 2
        perform fail-case
    end-if

    perform reset-case
    move "model failure" to test-name
    move 6 to test-mode
    perform run-agent
    if px-result-error not = "TEST_MODEL_FAILURE"
        or event-types(2) not = "run.failed"
        perform fail-case
    end-if

    perform reset-case
    move "missing tool dispatcher" to test-name
    move 1 to test-mode
    move spaces to px-tool-program
    perform run-agent
    if px-result-error not = "TOOL_NOT_FOUND" or tool-count not = 0
        perform fail-case
    end-if

    perform reset-case
    move "tool failure" to test-name
    move 7 to test-mode
    perform run-agent
    if px-result-error not = "TEST_TOOL_FAILURE"
        or event-types(3) not = "run.failed"
        perform fail-case
    end-if

    perform reset-case
    move "invalid response bounds" to test-name
    move 8 to test-mode
    perform run-agent
    if px-result-error not = "INVALID_REQUEST" or tool-count not = 0
        perform fail-case
    end-if

    perform reset-case
    move "context capacity" to test-name
    move 64 to px-message-count of px-session
    perform run-agent
    if px-result-error not = "AGENT_CONTEXT_BUDGET"
        or model-count not = 0
        perform fail-case
    end-if

    perform reset-case
    move "default step budget" to test-name
    move 2 to test-mode
    move 0 to px-max-steps
    perform run-agent
    if px-result-error not = "AGENT_MAX_STEPS" or model-count not = 8
        or tool-count not = 8 or px-max-steps not = 0
        perform fail-case
    end-if

    perform reset-case
    move "missing model" to test-name
    move "missing-model-program" to px-model-program
    perform run-agent
    if px-result-error not = "MODEL_ERROR"
        or event-types(2) not = "run.failed"
        perform fail-case
    end-if

    perform reset-case
    move "optional callbacks" to test-name
    move spaces to px-event-program px-policy-program
    perform run-agent
    if px-result-error not = spaces or px-result-output not = "hello"
        perform fail-case
    end-if

    if failures not = 0
        display "FAIL: " failures " assertions"
        move 1 to return-code
    else
        display "PASS: 14 native COBOL agent cases"
        move 0 to return-code
    end-if
    goback.
reset-case.
    initialize px-options px-session px-prompt px-result
    move low-values to px-user-data
    move "test-model" to px-model-program
    move "test-tool" to px-tool-program
    move "test-policy" to px-policy-program
    move "test-events" to px-event-program
    move 8 to px-max-steps
    move "hello" to px-prompt-text
    move 5 to px-prompt-length.
run-agent.
    move px-session to saved-session
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-session not = saved-session
        perform fail-case
    end-if.
fail-case.
    add 1 to failures
    display "FAIL: " trim(test-name)
        " error=" trim(px-result-error).
end program core-tests.

identification division.
program-id. test-model.
data division.
linkage section.
copy "api.cpy".
copy "state.cpy".
procedure division using px-session px-response px-user-data px-status.
    add 1 to model-count
    move "hello" to px-answer
    move 5 to px-answer-length
    if test-mode = 6
        move "TEST_MODEL_FAILURE" to px-status
        goback
    end-if
    if test-mode = 8
        move 9 to px-call-count
        goback
    end-if
    if test-mode = 3 move 10 to px-output-tokens end-if
    if model-count = 2 and test-mode = 1
        if px-message-count = 3 and px-role(1) = "user"
            and px-content(1) = "hello"
            and px-role(2) = "assistant" and px-role(3) = "tool"
            and px-content(3) = '{"text":"hi"}'
            and px-content-length(3) = 13
            and px-message-call-id(3) = "c1"
            move 1 to history-valid
        end-if
    end-if
    if test-mode = 2 or ((test-mode = 1 or 5 or 7)
        and model-count = 1)
        move spaces to px-answer
        move 0 to px-answer-length
        move 1 to px-call-count
        move "c1" to px-call-id(1)
        move "echo" to px-call-name(1)
        move '{"text":"hi"}' to px-call-input(1)
        move 13 to px-call-input-length(1)
    end-if
    goback.
end program test-model.

identification division.
program-id. test-tool.
data division.
linkage section.
copy "api.cpy".
copy "state.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    add 1 to tool-count
    if test-mode = 7
        move "TEST_TOOL_FAILURE" to px-status
    else
        move px-tool-input to px-tool-output
        move px-tool-input-length to px-tool-output-length
    end-if
    goback.
end program test-tool.

identification division.
program-id. test-policy.
data division.
linkage section.
copy "api.cpy".
copy "state.cpy".
procedure division using px-action px-user-data px-status.
    add 1 to policy-count
    if test-mode = 4 or (test-mode = 5
        and px-action-kind = "tool.invoke")
        move "DENIED" to px-status
    end-if
    goback.
end program test-policy.

identification division.
program-id. test-events.
data division.
linkage section.
copy "api.cpy".
copy "state.cpy".
procedure division using px-event px-user-data px-status.
    add 1 to event-count
    if event-count <= 32
        move px-event-kind to event-types(event-count)
    end-if
    goback.
end program test-events.
