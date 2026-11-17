       >>source format free
identification division.
program-id. governance-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "api.cpy".
copy "governance-state.cpy".
01 children.
   05 child-entry occurs 3 times.
      10 ch-depth binary-long.
      10 ch-max-depth binary-long.
      10 ch-released pic 9.
01 active-children binary-long.
01 parent-depth binary-long.
01 parent-max-depth binary-long.
01 max-children binary-long.
01 request-allowed pic x(64).
01 child-index binary-long.
01 next-depth binary-long.
01 delegate-error pic x(64).
01 failures binary-long value 0.
procedure division.
    perform test-tool-scope
    perform test-depth-limit
    perform test-child-count
    perform test-sibling-budget
    perform test-cancellation
    perform test-final-arguments
    if failures = 0
        display "PASS: 6 native COBOL delegation governance cases"
        move 0 to return-code
    else
        display "FAIL: " failures " governance assertions"
        move 1 to return-code
    end-if
    goback.

reset-case.
    initialize px-options px-session px-prompt px-result
    initialize px-user-data
    initialize children
    move 0 to active-children
    move 0 to parent-depth
    move 1 to parent-max-depth
    move 2 to max-children
    move "record" to request-allowed
    move "safe" to gv-target
    move 1 to gv-budget
    move 0 to gv-model-count gv-tool-count gv-policy-count
    move 0 to gv-cancel gv-mutate
    move spaces to delegate-error.

delegate-child.
    move spaces to delegate-error
    compute next-depth = parent-depth + 1
    if next-depth > parent-max-depth
        move "DELEGATION_DEPTH" to delegate-error
        exit paragraph
    end-if
    if request-allowed = spaces or request-allowed not = "record"
        move "DELEGATION_SCOPE" to delegate-error
        exit paragraph
    end-if
    if active-children >= max-children
        move "DELEGATION_CHILDREN" to delegate-error
        exit paragraph
    end-if
    if gv-budget <= 0
        move "DELEGATION_BUDGET" to delegate-error
        exit paragraph
    end-if
    add 1 to active-children
    move next-depth to ch-depth(child-index)
    move parent-max-depth to ch-max-depth(child-index)
    move 0 to ch-released(child-index).

release-child.
    if ch-released(child-index) = 1
        exit paragraph
    end-if
    move 1 to ch-released(child-index)
    subtract 1 from active-children.

run-child.
    initialize px-options px-session px-prompt px-result
    move "gov-model" to px-model-program
    move "gov-tool" to px-tool-program
    move "gov-policy" to px-policy-program
    move "gov-cancel" to px-cancel-program
    move "gov-before-tool" to px-before-tool-program
    move 3 to px-max-steps
    move 1 to px-allowed-tool-count
    move "record" to px-allowed-tools(1)
    move 1 to px-require-policy
    move 1 to px-require-tool-scope
    move "record once" to px-prompt-text
    move 11 to px-prompt-length
    move 0 to px-message-count
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    end-call.

test-tool-scope.
    perform reset-case
    move "parent_only" to request-allowed
    move 1 to child-index
    perform delegate-child
    if delegate-error not = "DELEGATION_SCOPE"
        perform fail-case
    end-if
    if gv-tool-count not = 0 or active-children not = 0
        perform fail-case
    end-if.

test-depth-limit.
    perform reset-case
    move "record" to request-allowed
    move 2 to gv-budget
    move 1 to child-index
    perform delegate-child
    if delegate-error not = spaces
        perform fail-case
    end-if
    move ch-depth(child-index) to parent-depth
    move ch-max-depth(child-index) to parent-max-depth
    move 2 to child-index
    perform delegate-child
    if delegate-error not = "DELEGATION_DEPTH"
        perform fail-case
    end-if
    if gv-tool-count not = 0
        perform fail-case
    end-if
    move 1 to child-index
    perform release-child
    if active-children not = 0
        perform fail-case
    end-if.

test-child-count.
    perform reset-case
    move "record" to request-allowed
    move 1 to max-children
    move 2 to gv-budget
    move 1 to child-index
    perform delegate-child
    if delegate-error not = spaces
        perform fail-case
    end-if
    move 2 to child-index
    perform delegate-child
    if delegate-error not = "DELEGATION_CHILDREN"
        perform fail-case
    end-if
    move 1 to child-index
    perform release-child
    move 2 to child-index
    perform delegate-child
    if delegate-error not = spaces
        perform fail-case
    end-if
    perform release-child
    if gv-tool-count not = 0 or active-children not = 0
        perform fail-case
    end-if.

test-sibling-budget.
    perform reset-case
    move "record" to request-allowed
    move 1 to gv-budget
    move 1 to child-index
    perform delegate-child
    if delegate-error not = spaces
        perform fail-case
    end-if
    move 2 to child-index
    perform delegate-child
    if delegate-error not = spaces
        perform fail-case
    end-if
    move "first" to gv-target
    move 0 to gv-model-count gv-mutate gv-cancel
    perform run-child
    if px-result-error not = spaces or gv-tool-count not = 1
        perform fail-case
    end-if
    if gv-budget not = 0
        perform fail-case
    end-if
    move "second" to gv-target
    move 0 to gv-model-count
    perform run-child
    if px-result-error not = "DELEGATION_BUDGET"
        perform fail-case
    end-if
    if gv-tool-count not = 1
        perform fail-case
    end-if
    move 1 to child-index
    perform release-child
    move 2 to child-index
    perform release-child.

test-cancellation.
    perform reset-case
    move "record" to request-allowed
    move 1 to child-index
    perform delegate-child
    if delegate-error not = spaces
        perform fail-case
    end-if
    move "safe" to gv-target
    move 0 to gv-model-count gv-mutate
    move 1 to gv-cancel
    perform run-child
    if px-result-error not = "AGENT_CANCELLED"
        perform fail-case
    end-if
    if gv-model-count not = 0 or gv-tool-count not = 0
        perform fail-case
    end-if
    perform release-child.

test-final-arguments.
    perform reset-case
    move "record" to request-allowed
    move 1 to child-index
    perform delegate-child
    if delegate-error not = spaces
        perform fail-case
    end-if
    move "safe" to gv-target
    move 0 to gv-model-count gv-cancel
    move 1 to gv-mutate
    perform run-child
    if px-result-error not = "POLICY_ERROR"
        perform fail-case
    end-if
    if gv-model-count not = 1 or gv-tool-count not = 0
        perform fail-case
    end-if
    if gv-policy-count < 2
        perform fail-case
    end-if
    perform release-child.

fail-case.
    add 1 to failures
    display "FAIL: governance error=" trim(px-result-error)
        " delegate=" trim(delegate-error).
end program governance-tests.

identification division.
program-id. gov-model recursive.
data division.
linkage section.
copy "api.cpy".
copy "governance-state.cpy".
procedure division using px-session px-response px-user-data px-status.
    add 1 to gv-model-count
    if gv-model-count = 1
        move spaces to px-answer
        move 0 to px-answer-length
        move 1 to px-call-count
        move "c1" to px-call-id(1)
        move "record" to px-call-name(1)
        evaluate gv-target
            when "first"
                move '{"target":"first"}' to px-call-input(1)
                move 18 to px-call-input-length(1)
            when "second"
                move '{"target":"second"}' to px-call-input(1)
                move 19 to px-call-input-length(1)
            when other
                move '{"target":"safe"}' to px-call-input(1)
                move 16 to px-call-input-length(1)
        end-evaluate
    else
        move "done" to px-answer
        move 4 to px-answer-length
        move 0 to px-call-count
    end-if
    goback.
end program gov-model.

identification division.
program-id. gov-tool recursive.
data division.
linkage section.
copy "api.cpy".
copy "governance-state.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    if gv-budget <= 0
        move "DELEGATION_BUDGET" to px-status
        goback
    end-if
    subtract 1 from gv-budget
    add 1 to gv-tool-count
    move px-tool-input to px-tool-output
    move px-tool-input-length to px-tool-output-length
    goback.
end program gov-tool.

identification division.
program-id. gov-policy recursive.
data division.
linkage section.
copy "api.cpy".
copy "governance-state.cpy".
procedure division using px-action px-user-data px-status.
    if px-action-kind = "tool.invoke"
        add 1 to gv-policy-count
        if px-action-tool not = "record"
            move "DENIED" to px-status
        else
            if px-action-input-length = 20
                and px-action-input(1:20) = '{"target":"blocked"}'
                move "DENIED" to px-status
            end-if
        end-if
    end-if
    goback.
end program gov-policy.

identification division.
program-id. gov-cancel recursive.
data division.
linkage section.
copy "api.cpy".
copy "governance-state.cpy".
procedure division using px-action px-user-data px-status.
    if gv-cancel = 1
        move "AGENT_CANCELLED" to px-status
    end-if
    goback.
end program gov-cancel.

identification division.
program-id. gov-before-tool recursive.
data division.
linkage section.
copy "api.cpy".
copy "governance-state.cpy".
procedure division using px-call px-user-data px-status.
    if gv-mutate = 1
        move '{"target":"blocked"}' to px-tool-input
        move 20 to px-tool-input-length
    end-if
    goback.
end program gov-before-tool.
