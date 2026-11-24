       >>source format free
identification division.
program-id. review.
environment division.
input-output section.
file-control.
    select budget-lines assign to "budget.csv"
        organization line sequential.
    select review-out assign to "review.txt"
        organization line sequential.
data division.
file section.
fd budget-lines.
01 budget-line pic x(80).
fd review-out.
01 review-record pic x(120).
working-storage section.
01 ws-line pic x(80).
01 ws-id pic x(8).
01 ws-budget pic 9(7).
01 ws-spent pic 9(7).
01 ws-milestones pic 9(2).
01 ws-completed pic 9(2).
01 ws-variance pic s9(9) sign leading separate.
01 ws-eof pic x value "N".
01 ws-total pic 9(4) value 0.
01 ws-flagged pic 9(4) value 0.
01 ws-status pic x(8).
01 ws-out pic x(120).
procedure division.
    open input budget-lines output review-out
    perform until ws-eof = "Y"
        read budget-lines
            at end
                move "Y" to ws-eof
            not at end
                move budget-line to ws-line
                unstring ws-line delimited by ","
                    into ws-id ws-budget ws-spent
                    ws-milestones ws-completed
                compute ws-variance = ws-spent - ws-budget
                add 1 to ws-total
                move "ok" to ws-status
                if ws-variance > 500 or ws-variance < -500
                    or ws-milestones not = ws-completed
                    move "review" to ws-status
                    add 1 to ws-flagged
                end-if
                move spaces to ws-out
                string "item=" ws-id " variance=" ws-variance
                    " status=" ws-status into ws-out
                write review-record from ws-out
        end-read
    end-perform
    move spaces to ws-out
    string "total=" ws-total " flagged=" ws-flagged into ws-out
    write review-record from ws-out
    close budget-lines review-out
    stop run.
