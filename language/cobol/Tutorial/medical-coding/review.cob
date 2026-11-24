       >>source format free
identification division.
program-id. review.
environment division.
input-output section.
file-control.
    select patient-records assign to "records.csv"
        organization line sequential.
    select review-out assign to "review.txt"
        organization line sequential.
data division.
file section.
fd patient-records.
01 record-line pic x(80).
fd review-out.
01 review-record pic x(120).
working-storage section.
01 ws-line pic x(80).
01 ws-id pic x(8).
01 ws-age pic 9(3).
01 ws-diagnoses pic 9(2).
01 ws-procedures pic 9(2).
01 ws-eof pic x value "N".
01 ws-total pic 9(4) value 0.
01 ws-complete-count pic 9(4) value 0.
01 ws-review-count pic 9(4) value 0.
01 ws-complete pic x(3).
01 ws-code pic x(12).
01 ws-status pic x(16).
01 ws-out pic x(120).
procedure division.
    open input patient-records output review-out
    perform until ws-eof = "Y"
        read patient-records
            at end
                move "Y" to ws-eof
            not at end
                move record-line to ws-line
                unstring ws-line delimited by ","
                    into ws-id ws-age ws-diagnoses ws-procedures
                add 1 to ws-total
                move "YES" to ws-complete
                move "draft_only" to ws-status
                if ws-age < 18 or ws-diagnoses < 1
                    or ws-procedures < 1
                    move "NO" to ws-complete
                    move "REVIEW" to ws-code
                    move "review_required" to ws-status
                    add 1 to ws-review-count
                else
                    if ws-diagnoses >= 2
                        move "DRG-DRAFT-A" to ws-code
                    else
                        move "DRG-DRAFT-B" to ws-code
                    end-if
                    add 1 to ws-complete-count
                end-if
                move spaces to ws-out
                string "record=" ws-id " complete=" ws-complete
                    " code=" ws-code " status=" ws-status
                    into ws-out
                write review-record from ws-out
        end-read
    end-perform
    move spaces to ws-out
    string "total=" ws-total " complete=" ws-complete-count
        " review=" ws-review-count into ws-out
    write review-record from ws-out
    close patient-records review-out
    stop run.
