       >>source format free
identification division.
program-id. behavior-tests.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "api.cpy".
copy "behavior-state.cpy".
01 saved-session.
   copy "history.cpy".
01 failures binary-long value 0.
01 test-name pic x(64).
procedure division.
    perform final-arguments-case
    perform final-name-allowlist-case
    perform final-name-reauthorize-case
    perform unchanged-authorization-case
    perform initial-denial-case
    perform startup-cleanup-case
    perform after-run-continue-case
    perform cleanup-failclosed-case
    if failures = 0
        display "PASS: 8 native COBOL behavior cases"
        move 0 to return-code
    else
        display "FAIL: " failures " behavior assertions"
        move 1 to return-code
    end-if
    goback.
final-arguments-case.
    perform reset-case
    move "final arguments" to test-name
    move 1 to bh-mode
    move "behavior-before-tool" to px-before-tool-program
    perform run-agent
    if px-result-error not = spaces
        or px-result-output not = "done"
        or bh-tool-count not = 1
        or bh-before-tool-count not = 1
        or bh-tool-policy-count not = 2
        or bh-policy-args(1)(1:20) not = '{"value":"original"}'
        or bh-policy-args(2)(1:18) not = '{"value":"edited"}'
        or bh-last-input-length not = 18
        or bh-last-input(1:18) not = '{"value":"edited"}'
        perform fail-case
    end-if.
final-name-allowlist-case.
    perform reset-case
    move "final name allowlist" to test-name
    move 2 to bh-mode
    move "behavior-before-tool" to px-before-tool-program
    move 1 to px-allowed-tool-count
    move "echo" to px-allowed-tools(1)
    perform run-agent
    if px-result-error not = "AGENT_TOOL_NOT_ALLOWED"
        or bh-tool-count not = 0
        or bh-other-count not = 0
        or bh-before-tool-count not = 1
        or bh-tool-policy-count not = 1
        perform fail-case
    end-if.
final-name-reauthorize-case.
    perform reset-case
    move "final name reauthorize" to test-name
    move 3 to bh-mode
    move "behavior-before-tool" to px-before-tool-program
    move 2 to px-allowed-tool-count
    move "echo" to px-allowed-tools(1)
    move "other" to px-allowed-tools(2)
    perform run-agent
    if px-result-error not = spaces
        or px-result-output not = "done"
        or bh-tool-count not = 0
        or bh-other-count not = 1
        or bh-tool-policy-count not = 2
        or bh-policy-names(1)(1:4) not = "echo"
        or bh-policy-names(2)(1:5) not = "other"
        perform fail-case
    end-if.
unchanged-authorization-case.
    perform reset-case
    move "unchanged single authorization" to test-name
    move 4 to bh-mode
    move "behavior-before-tool" to px-before-tool-program
    perform run-agent
    if px-result-error not = spaces
        or px-result-output not = "done"
        or bh-tool-count not = 1
        or bh-before-tool-count not = 1
        or bh-tool-policy-count not = 1
        perform fail-case
    end-if.
initial-denial-case.
    perform reset-case
    move "initial denial" to test-name
    move 5 to bh-mode
    move "behavior-before-tool" to px-before-tool-program
    perform run-agent
    if px-result-error not = "POLICY_ERROR"
        or bh-before-tool-count not = 0
        or bh-tool-count not = 0
        or bh-tool-policy-count not = 1
        perform fail-case
    end-if.
startup-cleanup-case.
    perform reset-case
    move "startup cleanup" to test-name
    move 8 to bh-mode
    move "behavior-before-run" to px-before-run-program
    move "behavior-after-run" to px-after-run-program
    move "behavior-before-run-2" to px-before-run-program-2
    move "behavior-after-run-2" to px-after-run-program-2
    perform run-agent
    if px-result-error not = "STARTUP_FAILED"
        or bh-before-run-count not = 2
        or bh-after-run-count not = 2
        or bh-event-count not = 0
        or bh-model-count not = 0
        perform fail-case
    end-if.
after-run-continue-case.
    perform reset-case
    move "after-run continue" to test-name
    move 6 to bh-mode
    move "behavior-after-run" to px-after-run-program
    move "behavior-after-run-2" to px-after-run-program-2
    perform run-agent
    if px-result-error not = "TEST_MODEL_FAILURE"
        or bh-after-run-count not = 2
        or bh-event-count not = 2
        or bh-event-types(1) not = "run.started"
        or bh-event-types(2) not = "run.failed"
        perform fail-case
    end-if.
cleanup-failclosed-case.
    perform reset-case
    move "cleanup fail closed" to test-name
    move 7 to bh-mode
    move "behavior-after-run" to px-after-run-program
    move "behavior-after-run-2" to px-after-run-program-2
    perform run-agent
    if px-result-error not = "CLEANUP_FAILED"
        or bh-after-run-count not = 2
        or bh-event-count not = 2
        or bh-event-types(1) not = "run.started"
        or bh-event-types(2) not = "run.failed"
        perform fail-case
    end-if.
reset-case.
    initialize px-options px-session px-prompt px-result
    move low-values to px-user-data
    move "behavior-model" to px-model-program
    move "behavior-tool" to px-tool-program
    move "behavior-policy" to px-policy-program
    move "behavior-events" to px-event-program
    move 8 to px-max-steps
    move "go" to px-prompt-text
    move 2 to px-prompt-length.
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
end program behavior-tests.

identification division.
program-id. behavior-model recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-session px-response px-user-data px-status.
    add 1 to bh-model-count
    if bh-mode = 6
        move "TEST_MODEL_FAILURE" to px-status
        goback
    end-if
    if bh-mode = 8
        move "MODEL_SHOULD_NOT_RUN" to px-status
        goback
    end-if
    if bh-mode >= 1 and bh-mode <= 5 and bh-model-count = 1
        move spaces to px-answer
        move 0 to px-answer-length
        move 1 to px-call-count
        move "c1" to px-call-id(1)
        move "echo" to px-call-name(1)
        if bh-mode = 1
            move '{"value":"original"}' to px-call-input(1)
            move 20 to px-call-input-length(1)
        else
            move '{}' to px-call-input(1)
            move 2 to px-call-input-length(1)
        end-if
        goback
    end-if
    move "done" to px-answer
    move 4 to px-answer-length
    move 0 to px-call-count
    goback.
end program behavior-model.

identification division.
program-id. behavior-tool recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    if px-tool-name = "other"
        add 1 to bh-other-count
    else
        add 1 to bh-tool-count
    end-if
    move px-tool-name to bh-last-name
    move px-tool-input to bh-last-input
    move px-tool-input-length to bh-last-input-length
    move px-tool-input to px-tool-output
    move px-tool-input-length to px-tool-output-length
    goback.
end program behavior-tool.

identification division.
program-id. behavior-policy recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-action px-user-data px-status.
    if px-action-kind = "tool.invoke"
        add 1 to bh-tool-policy-count
        if bh-tool-policy-count <= 4
            move px-action-tool
                to bh-policy-names(bh-tool-policy-count)
            move px-action-input
                to bh-policy-args(bh-tool-policy-count)
        end-if
        if bh-mode = 5
            move "DENIED" to px-status
        end-if
    end-if
    goback.
end program behavior-policy.

identification division.
program-id. behavior-events recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-event px-user-data px-status.
    add 1 to bh-event-count
    if bh-event-count <= 16
        move px-event-kind to bh-event-types(bh-event-count)
    end-if
    goback.
end program behavior-events.

identification division.
program-id. behavior-before-run recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-action px-user-data px-status.
    add 1 to bh-before-run-count
    add 1 to bh-order-count
    if bh-order-count <= 16
        move "before1" to bh-order(bh-order-count)
    end-if
    goback.
end program behavior-before-run.

identification division.
program-id. behavior-before-run-2 recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-action px-user-data px-status.
    add 1 to bh-before-run-count
    add 1 to bh-order-count
    if bh-order-count <= 16
        move "before2" to bh-order(bh-order-count)
    end-if
    if bh-mode = 8
        move "STARTUP_FAILED" to px-status
    end-if
    goback.
end program behavior-before-run-2.

identification division.
program-id. behavior-after-run recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-result px-user-data px-status.
    add 1 to bh-after-run-count
    add 1 to bh-order-count
    if bh-order-count <= 16
        move "after1" to bh-order(bh-order-count)
    end-if
    if bh-mode = 6 or bh-mode = 7
        move "CLEANUP_FAILED" to px-status
    end-if
    goback.
end program behavior-after-run.

identification division.
program-id. behavior-after-run-2 recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-result px-user-data px-status.
    add 1 to bh-after-run-count
    add 1 to bh-order-count
    if bh-order-count <= 16
        move "after2" to bh-order(bh-order-count)
    end-if
    goback.
end program behavior-after-run-2.

identification division.
program-id. behavior-before-tool recursive.
data division.
linkage section.
copy "api.cpy".
copy "behavior-state.cpy".
procedure division using px-call px-user-data px-status.
    add 1 to bh-before-tool-count
    if bh-mode = 1
        move '{"value":"edited"}' to px-tool-input
        move 18 to px-tool-input-length
    end-if
    if bh-mode = 2 or bh-mode = 3
        move "other" to px-tool-name
    end-if
    goback.
end program behavior-before-tool.
