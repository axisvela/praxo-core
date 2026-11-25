       >>source format free
identification division.
program-id. cobol-batch-analyst.
environment division.
configuration section.
repository. function all intrinsic.
input-output section.
file-control.
    select exceptions-file assign to ws-exceptions-path
        organization is line sequential.
    select advisory-file assign to ws-advisory-path
        organization is line sequential.
data division.
file section.
fd exceptions-file.
01 exception-line pic x(512).
fd advisory-file
    record is varying in size from 1 to 1024
    depending on ws-advisory-length.
01 advisory-line pic x(1024).
working-storage section.
copy "api.cpy".
copy "application-state.cpy".
01 ws-exceptions-path pic x(256) value "exceptions.tsv".
01 ws-advisory-path pic x(256) value "advisory.tsv".
01 ws-advisory-length binary-long.
01 ws-command-line pic x(512).
01 ws-test-found binary-long.
01 ws-eof pic 9.
01 ws-run-error pic x(64).
01 ws-record-id pic x(16).
01 ws-record-class pic x(16).
01 ws-difference pic x(16).
01 ws-mode pic x(16).
01 ws-tenant pic x(32) value "bank-ops".
01 ws-found binary-long.
01 ws-index binary-long.
01 ws-count pic z(4)9.
01 ws-check-error pic x(64).
01 ws-batch-reviewed binary-long.
01 ws-batch-denied binary-long.
procedure division.
    accept ws-command-line from command-line
    inspect ws-command-line tallying ws-test-found for all "--test"
    accept ws-tenant from environment "PRAXO_TENANT"
    if function trim(ws-tenant) = spaces
        move "bank-ops" to ws-tenant
    end-if
    if ws-test-found > 0
        perform run-tests
        stop run
    end-if
    perform run-batch
    stop run.

run-batch.
    move 0 to ws-batch-reviewed ws-batch-denied
    open input exceptions-file
    open output advisory-file
    move 0 to ws-eof
    perform until ws-eof = 1
        read exceptions-file into exception-line
            at end move 1 to ws-eof
            not at end perform process-file-record
        end-read
    end-perform
    close exceptions-file advisory-file
    move ws-batch-reviewed to ws-count
    display "reviewed=" function trim(ws-count) " denied="
        function trim(ws-batch-denied).

process-file-record.
    initialize ws-record-id ws-record-class ws-difference
    unstring exception-line delimited by ","
        into ws-record-id ws-record-class ws-difference
    end-unstring
    if function trim(ws-record-id) = spaces
        exit paragraph
    end-if
    move "review" to ws-mode
    perform prepare-run
    if ws-run-error not = spaces
        add 1 to ws-batch-denied
        move as-executions to ws-count
        display "denied: " function trim(ws-record-id) " error="
            function trim(ws-run-error) " executions="
            function trim(ws-count)
        exit paragraph
    end-if
    if as-advisory-saved = 1
        add 1 to ws-batch-reviewed
        move spaces to advisory-line
        string function trim(as-record-id) ","
            function trim(as-record-class) ","
            function trim(as-diagnosis) ","
            function trim(as-rationale)
            into advisory-line
        end-string
        compute ws-advisory-length = function length(
            function trim(advisory-line trailing))
        write advisory-line
        move as-reads to ws-count
        display "reviewed: " function trim(as-record-id)
            " advisory=1 reads=" function trim(ws-count)
            " drafts=1 executions=0"
    else
        add 1 to ws-batch-denied
        display "denied: " function trim(as-record-id)
            " no advisory; executions=0"
    end-if.

prepare-run.
    initialize px-options px-session px-prompt px-result
    initialize application-state
    move ws-tenant to as-tenant
    move ws-record-id to as-record-id
    move ws-record-class to as-record-class
    move ws-difference to as-difference
    move ws-mode to as-mode
    move 0 to as-phase as-model-count as-reads as-drafts
        as-executions as-advisory-saved as-trace-count
    move "analyst-model" to px-model-program
    move "analyst-tool" to px-tool-program
    move "analyst-policy" to px-policy-program
    move "analyst-event" to px-event-program
    move 1 to px-require-policy
    move 1 to px-require-tool-scope
    move 3 to px-allowed-tool-count
    move "read_exception" to px-allowed-tools(1)
    move "draft_advisory" to px-allowed-tools(2)
    move "post_adjustment" to px-allowed-tools(3)
    move 6 to px-max-steps
    string "Review exception " function trim(ws-record-id)
        " for tenant " function trim(ws-tenant)
        ". Use read_exception, then draft a review-only advisory."
        " Never post an adjustment."
        into px-prompt-text
    end-string
    compute px-prompt-length = function length(
        function trim(px-prompt-text trailing))
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    move px-result-error to ws-run-error.

run-tests.
    perform test-public
    perform test-private
    perform test-direct
    perform test-tenant
    perform test-weak
    display "COBOL batch analyst self-test: passed".

test-public.
    move "002" to ws-record-id
    move "public" to ws-record-class
    move "25.00" to ws-difference
    move "review" to ws-mode
    move "bank-ops" to ws-tenant
    perform prepare-run
    move 0 to ws-found
    perform varying ws-index from 1 by 1
        until ws-index > as-trace-count
        inspect as-trace(ws-index) tallying ws-found
            for all "read_exception"
    end-perform
    if ws-run-error not = spaces or as-drafts not = 1
        or as-advisory-saved not = 1 or as-executions not = 0
        or as-reads not = 1 or ws-found = 0
        move "public review" to ws-check-error
        perform fail-test
    end-if
    display "public: reviewed advisory=1 executions=0".

test-private.
    move "003" to ws-record-id
    move "private" to ws-record-class
    move "-1.00" to ws-difference
    move "review" to ws-mode
    move "bank-ops" to ws-tenant
    perform prepare-run
    if ws-run-error = spaces or as-reads not = 0
        or as-drafts not = 0 or as-advisory-saved not = 0
        move "private denial" to ws-check-error
        perform fail-test
    end-if
    display "private: denied before read".

test-direct.
    move "004" to ws-record-id
    move "public" to ws-record-class
    move "10.00" to ws-difference
    move "direct" to ws-mode
    move "bank-ops" to ws-tenant
    perform prepare-run
    if ws-run-error = spaces or as-executions not = 0
        or as-drafts not = 0 or as-advisory-saved not = 0
        move "direct denial" to ws-check-error
        perform fail-test
    end-if
    display "direct: denied with zero effects".

test-tenant.
    move "005" to ws-record-id
    move "public" to ws-record-class
    move "5.00" to ws-difference
    move "review" to ws-mode
    move "other" to ws-tenant
    perform prepare-run
    if ws-run-error = spaces or as-model-count not = 0
        or as-reads not = 0 or as-advisory-saved not = 0
        move "tenant denial" to ws-check-error
        perform fail-test
    end-if
    display "tenant: denied before model".

test-weak.
    move "006" to ws-record-id
    move "public" to ws-record-class
    move "7.00" to ws-difference
    move "weak" to ws-mode
    move "bank-ops" to ws-tenant
    perform prepare-run
    if ws-run-error = spaces or as-drafts not = 0
        or as-advisory-saved not = 0 or as-executions not = 0
        move "weak advisory denial" to ws-check-error
        perform fail-test
    end-if
    display "weak: denied without rationale".

fail-test.
    display "FAILED: " function trim(ws-check-error) upon stderr
    stop run returning 1.

end program cobol-batch-analyst.

identification division.
program-id. analyst-model recursive.
data division.
linkage section.
copy "api.cpy".
copy "application-state.cpy".
procedure division using px-session px-response px-user-data px-status.
    add 1 to as-model-count
    if as-mode = "direct"
        move 1 to px-call-count
        move "post-1" to px-call-id(1)
        move "post_adjustment" to px-call-name(1)
        string '{"record_id":"' function trim(as-record-id) '"}'
            into px-call-input(1)
        end-string
        compute px-call-input-length(1) = function length(
            function trim(px-call-input(1) trailing))
        goback
    end-if
    if as-mode = "weak"
        move 1 to px-call-count
        move "draft-1" to px-call-id(1)
        move "draft_advisory" to px-call-name(1)
        string '{"record_id":"' function trim(as-record-id)
            '","review_only":true}' into px-call-input(1)
        end-string
        compute px-call-input-length(1) = function length(
            function trim(px-call-input(1) trailing))
        goback
    end-if
    if as-phase = 0
        move 1 to px-call-count
        move "read-1" to px-call-id(1)
        move "read_exception" to px-call-name(1)
        string '{"record_id":"' function trim(as-record-id) '"}'
            into px-call-input(1)
        end-string
        compute px-call-input-length(1) = function length(
            function trim(px-call-input(1) trailing))
        move 1 to as-phase
    else
        if as-phase = 1
            string "Record " function trim(as-record-id)
                " differs by " function trim(as-difference) "."
                into as-diagnosis
            end-string
            string "A nonzero batch difference needs operator review;"
                " the agent may draft advice but may not post."
                into as-rationale
            end-string
            move 1 to px-call-count
            move "draft-1" to px-call-id(1)
            move "draft_advisory" to px-call-name(1)
            string '{"record_id":"' function trim(as-record-id)
                '","review_only":true,"diagnosis":"'
                function trim(as-diagnosis) '","rationale":"'
                function trim(as-rationale) '"}'
                into px-call-input(1)
            end-string
            compute px-call-input-length(1) = function length(
                function trim(px-call-input(1) trailing))
            move 2 to as-phase
        else
            move "review_complete" to px-answer
            move 15 to px-answer-length
            move 0 to px-call-count
        end-if
    end-if
    goback.
end program analyst-model.

identification division.
program-id. analyst-tool recursive.
data division.
linkage section.
copy "api.cpy".
copy "application-state.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    evaluate px-tool-name
        when "read_exception"
            if as-record-class not = "public"
                move "RECORD_DENIED" to px-status
                goback
            end-if
            add 1 to as-reads
            string '{"record_id":"' function trim(as-record-id)
                '","classification":"' function trim(as-record-class)
                '","difference":"' function trim(as-difference) '"}'
                into px-tool-output
            end-string
            compute px-tool-output-length = function length(
                function trim(px-tool-output trailing))
        when "draft_advisory"
            if as-record-class not = "public"
                or function trim(as-diagnosis) = spaces
                or function trim(as-rationale) = spaces
                move "ADVISORY_INVALID" to px-status
                goback
            end-if
            add 1 to as-drafts
            move 1 to as-advisory-saved
            move '{"saved":true,"review_only":true,"executions":0}'
                to px-tool-output
            compute px-tool-output-length = function length(
                function trim(px-tool-output trailing))
        when "post_adjustment"
            add 1 to as-executions
            move '{"posted":true}' to px-tool-output
            move 14 to px-tool-output-length
        when other
            move "TOOL_NOT_FOUND" to px-status
    end-evaluate
    goback.
end program analyst-tool.

identification division.
program-id. analyst-policy recursive.
data division.
working-storage section.
01 ws-found binary-long.
linkage section.
copy "api.cpy".
copy "application-state.cpy".
procedure division using px-action px-user-data px-status.
    if as-tenant not = "bank-ops"
        move "AGENT_POLICY_DENIED" to px-status
        goback
    end-if
    if px-action-kind = "model.generate"
        goback
    end-if
    if px-action-kind not = "tool.invoke"
        move "AGENT_POLICY_DENIED" to px-status
        goback
    end-if
    evaluate px-action-tool
        when "read_exception"
            if as-record-class not = "public"
                move "AGENT_POLICY_DENIED" to px-status
            end-if
        when "draft_advisory"
            move 0 to ws-found
            inspect px-action-input tallying ws-found
                for all '"review_only":true'
            if as-record-class not = "public"
                or function trim(as-diagnosis) = spaces
                or function trim(as-rationale) = spaces
                or ws-found = 0
                move "AGENT_POLICY_DENIED" to px-status
            end-if
        when other
            move "AGENT_POLICY_DENIED" to px-status
    end-evaluate
    goback.
end program analyst-policy.

identification division.
program-id. analyst-event recursive.
data division.
linkage section.
copy "api.cpy".
copy "application-state.cpy".
procedure division using px-event px-user-data px-status.
    if as-trace-count < 16
        add 1 to as-trace-count
        string function trim(px-event-kind) ":"
            function trim(px-event-tool)
            into as-trace(as-trace-count)
        end-string
    end-if
    goback.
end program analyst-event.
