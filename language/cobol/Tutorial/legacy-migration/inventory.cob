       >>source format free
identification division.
program-id. inventory.
environment division.
input-output section.
file-control.
    select catalog assign to "catalog.csv"
        organization line sequential.
    select inventory assign to "inventory.txt"
        organization line sequential.
data division.
file section.
fd catalog.
01 catalog-record pic x(80).
fd inventory.
01 inventory-record pic x(120).
working-storage section.
01 ws-line pic x(80).
01 ws-module pic x(16).
01 ws-kind pic x(8).
01 ws-status pic x(8).
01 ws-lines pic 9(5).
01 ws-eof pic x value "N".
01 ws-total pic 9(4) value 0.
01 ws-active pic 9(4) value 0.
01 ws-batch pic 9(4) value 0.
01 ws-out pic x(120).
procedure division.
    open input catalog output inventory
    perform until ws-eof = "Y"
        read catalog
            at end
                move "Y" to ws-eof
            not at end
                move catalog-record to ws-line
                unstring ws-line delimited by ","
                    into ws-module ws-kind ws-status ws-lines
                add 1 to ws-total
                if ws-status = "ACTIVE"
                    add 1 to ws-active
                end-if
                if ws-kind = "BATCH"
                    add 1 to ws-batch
                end-if
                move spaces to ws-out
                string "module=" ws-module " kind=" ws-kind
                    " status=" ws-status " lines=" ws-lines
                    into ws-out
                write inventory-record from ws-out
        end-read
    end-perform
    move spaces to ws-out
    string "total=" ws-total " active=" ws-active
        " batch=" ws-batch into ws-out
    write inventory-record from ws-out
    close catalog inventory
    stop run.
