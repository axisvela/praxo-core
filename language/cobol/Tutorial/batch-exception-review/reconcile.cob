       >>source format free
identification division.
program-id. reconcile.
environment division.
input-output section.
file-control.
    select ledger assign to "ledger.tsv"
        organization line sequential.
    select reconciliation assign to "reconciliation.tsv"
        organization line sequential.
data division.
file section.
fd ledger.
01 ledger-record.
    05 lr-id pic x(3).
    05 lr-comma-1 pic x.
    05 lr-booked pic 9(5).
    05 lr-comma-2 pic x.
    05 lr-actual pic 9(5).
fd reconciliation.
01 out-record.
    05 out-id pic x(3).
    05 out-comma pic x.
    05 out-diff pic +9(9).
working-storage section.
01 ws-eof pic x value "N".
01 ws-diff pic s9(9).
01 ws-count pic 9(4) value 0.
procedure division.
    open input ledger output reconciliation
    perform until ws-eof = "Y"
        read ledger
            at end
                move "Y" to ws-eof
            not at end
                compute ws-diff = lr-booked - lr-actual
                if ws-diff not = 0
                    move lr-id to out-id
                    move "," to out-comma
                    move ws-diff to out-diff
                    write out-record
                    add 1 to ws-count
                end-if
        end-read
    end-perform
    close ledger reconciliation
    display ws-count
    stop run.
