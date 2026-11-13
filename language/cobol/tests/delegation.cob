       >>source format free
identification division.
program-id. delegation-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "delegation.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division.
    initialize px-subagent-request px-subagent-task px-user-data
    move "parent-1" to px-sub-parent-session-id
    move "agent-1" to px-sub-agent-id
    move "do work" to px-sub-prompt
    move "fork" to px-sub-mode
    move "child-1" to px-sub-task-id
    move "2026-11-13T00:00:00Z" to px-sub-created-at
    move "2026-11-13T00:00:00Z" to px-sub-updated-at
    move "fake-subagent-runner" to px-sub-runner-program
    move "S" to px-user-data(1:1)
    call "praxo-delegation" using px-subagent-request
        px-subagent-task px-user-data px-status
    if px-status not = spaces
        display "delegation failed: " px-status
        stop run returning 1
    end-if
    if px-task-status not = "completed"
        display "unexpected task status: " px-task-status
        stop run returning 1
    end-if
    if px-task-error not = spaces
        display "unexpected task error: " px-task-error
        stop run returning 1
    end-if
    if px-task-output(1:px-task-output-length) not = "done"
        display "unexpected output: "
            px-task-output(1:px-task-output-length)
        stop run returning 1
    end-if
    if px-task-mode not = "fork"
        display "unexpected mode: " px-task-mode
        stop run returning 1
    end-if
    if function trim(px-task-parent-session-id) not = "parent-1"
        display "unexpected parent session"
        stop run returning 1
    end-if
    if function trim(px-task-agent-id) not = "agent-1"
        display "unexpected agent id"
        stop run returning 1
    end-if
    if function trim(px-task-id) not = "child-1"
        display "unexpected task id: " px-task-id
        stop run returning 1
    end-if
    move "E" to px-user-data(1:1)
    call "praxo-delegation" using px-subagent-request
        px-subagent-task px-user-data px-status
    if px-status not = spaces
        display "delegation failure returned status: " px-status
        stop run returning 1
    end-if
    if px-task-status not = "failed"
        display "unexpected failed status: " px-task-status
        stop run returning 1
    end-if
    if px-task-error not = "MODEL_FAIL"
        display "lost task error code: " px-task-error
        stop run returning 1
    end-if
    move spaces to px-sub-parent-session-id
    call "praxo-delegation" using px-subagent-request
        px-subagent-task px-user-data px-status
    if px-status not = "SUBAGENT_INVALID"
        display "expected SUBAGENT_INVALID, got: " px-status
        stop run returning 1
    end-if
    move "parent-1" to px-sub-parent-session-id
    move spaces to px-sub-agent-id
    call "praxo-delegation" using px-subagent-request
        px-subagent-task px-user-data px-status
    if px-status not = "SUBAGENT_INVALID"
        display "expected SUBAGENT_INVALID for agent, got: " px-status
        stop run returning 1
    end-if
    move "agent-1" to px-sub-agent-id
    move spaces to px-sub-runner-program
    call "praxo-delegation" using px-subagent-request
        px-subagent-task px-user-data px-status
    if px-status not = "SUBAGENT_INVALID"
        display "expected SUBAGENT_INVALID for runner, got: " px-status
        stop run returning 1
    end-if
    display "Delegation tests passed"
    stop run.
end program delegation-tests.

identification division.
program-id. fake-subagent-runner recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
linkage section.
copy "delegation.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-subagent-request px-subagent-result
    px-user-data px-status.
    move spaces to px-status
    if px-user-data(1:1) = "E"
        move "MODEL_FAIL" to px-status
        goback
    end-if
    move "child-1" to px-sub-result-task-id
    move 7 to px-sub-result-task-id-length
    move "agent-1" to px-sub-result-agent-id
    move 7 to px-sub-result-agent-id-length
    move "done" to px-sub-result-output
    move 4 to px-sub-result-output-length
    goback.
end program fake-subagent-runner.
