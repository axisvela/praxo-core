       >>source format free
identification division.
program-id. identity-policy-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "policy.cpy".
procedure division.
    initialize px-policy-request px-policy-result
    move 1 to px-pol-grant-count
    move "root" to px-pol-root(1)
    move 4 to px-pol-root-length(1)
    move "read" to px-pol-access(1)
    move 4 to px-pol-access-length(1)

    move "root/a.txt" to px-pol-target
    move 10 to px-pol-target-length
    move "read" to px-pol-need
    move 4 to px-pol-need-length
    call "praxo-policy" using px-policy-request px-policy-result
    if px-pol-error not = spaces or px-pol-allowed not = 1
        display "allowed path was rejected"
        stop run returning 1
    end-if

    move "root/../outside/x" to px-pol-target
    move 17 to px-pol-target-length
    call "praxo-policy" using px-policy-request px-policy-result
    if px-pol-allowed not = 0
        display "policy traversal was accepted"
        stop run returning 1
    end-if

    display "COBOL identity policy example passed"
    stop run.
