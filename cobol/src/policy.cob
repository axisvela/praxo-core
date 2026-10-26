       >>source format free
identification division.
program-id. praxo-policy recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
copy "path.cpy".
01 target-path pic x(4096).
01 target-length binary-long.
01 root-path pic x(4096).
01 root-length binary-long.
01 grant-index binary-long.
01 access-length binary-long.
01 access-text pic x(16).
01 match-access pic 9.
01 first-index binary-long.
01 second-index binary-long.
01 first-char pic x.
01 colon-count binary-long.
linkage section.
copy "policy.cpy".
procedure division using px-policy-request px-policy-result.
    initialize px-policy-result
    if px-pol-target-length < 1 or > 4096
        or px-pol-grant-count < 0 or > 32
        move "POLICY_ERROR" to px-pol-error
        goback
    end-if
    if px-pol-need-length < 1 or > 16
        move "POLICY_ERROR" to px-pol-error
        goback
    end-if
    move px-pol-need(1:px-pol-need-length) to access-text
    if access-text not = "read" and not = "write"
        and not = "readwrite"
        move "POLICY_ERROR" to px-pol-error
        goback
    end-if
    move px-pol-target(1:px-pol-target-length) to px-path-text
    move px-pol-target-length to px-path-length
    call "praxo-path-normalize" using px-path-request px-path-result
    if px-path-error not = spaces
        move "POLICY_ERROR" to px-pol-error
        goback
    end-if
    move px-path-normal(1:px-path-normal-length) to target-path
    move px-path-normal-length to target-length
    perform varying grant-index from 1 by 1
        until grant-index > px-pol-grant-count
        if px-pol-root-length(grant-index) < 1
            or > 1024
            move "POLICY_ERROR" to px-pol-error
            goback
        end-if
        move px-pol-access-length(grant-index) to access-length
        if access-length < 1 or > 16
            move "POLICY_ERROR" to px-pol-error
            goback
        end-if
        move px-pol-access(grant-index)(1:access-length) to access-text
        move 0 to match-access
        if access-text = "readwrite" or access-text = px-pol-need(1:px-pol-need-length)
            move 1 to match-access
        end-if
        if match-access = 1
            move px-pol-root(grant-index)(1:px-pol-root-length(grant-index))
                to px-path-text
            move px-pol-root-length(grant-index) to px-path-length
            call "praxo-path-normalize" using px-path-request px-path-result
            if px-path-error not = spaces
                move "POLICY_ERROR" to px-pol-error
                goback
            end-if
            move px-path-normal(1:px-path-normal-length) to root-path
            move px-path-normal-length to root-length
            perform check-prefix
            if px-pol-allowed = 1 goback end-if
        end-if
    end-perform
    goback.
check-prefix.
    move 0 to px-pol-allowed
    if root-length = 0 or target-length = 0 exit paragraph end-if
    if root-length = 1 and root-path(1:1) = "."
        if target-length >= 2
            if target-path(1:2) = ".."
                exit paragraph
            end-if
        end-if
        if target-path(1:1) = "/"
            exit paragraph
        end-if
        move 0 to colon-count
        inspect target-path(1:target-length)
            tallying colon-count for all ":"
        if colon-count > 0
            exit paragraph
        end-if
        move 1 to px-pol-allowed
        exit paragraph
    end-if
    if target-length = root-length
        if target-path(1:target-length) = root-path(1:root-length)
            move 1 to px-pol-allowed
        end-if
        exit paragraph
    end-if
    if target-length > root-length
        if target-path(1:root-length) = root-path(1:root-length)
            compute first-index = root-length + 1
            if target-path(first-index:1) = "/"
                move 1 to px-pol-allowed
            end-if
        end-if
    end-if.
end program praxo-policy.
