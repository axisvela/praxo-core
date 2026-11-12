       >>source format free
identification division.
program-id. harmovela-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "harmovela.cpy".
01 px-harmovela-event.
   05 px-harmovela-event-kind pic x(32).
   05 px-harmovela-event-tool pic x(64).
01 px-user-data pic x(4096).
01 capture redefines px-user-data.
   05 capture-mode pic x.
   05 capture-url pic x(1024).
   05 capture-body pic x(2048).
01 px-status pic x(64).
01 expected-json pic x(16384).
01 expected-length binary-long.
01 captured-length binary-long.
procedure division.
    move spaces to px-harmovela-options px-user-data
    move "fake-harmovela-transport" to px-harmovela-transport-program
    move "http://harmovela.test/aep/api/" to px-harmovela-base-url
    move "praxo-core" to px-harmovela-source
    move "0.2" to px-harmovela-spec
    move "run-123" to px-harmovela-id-prefix
    move "1794294000000000000" to px-harmovela-id-suffix
    move "2026-11-10T07:00:00.000000000Z"
        to px-harmovela-created-at
    move "tool.call" to px-harmovela-event-kind
    move "echo" to px-harmovela-event-tool
    move "S" to capture-mode
    call "praxo-harmovela" using px-harmovela-options
        px-harmovela-result px-harmovela-event px-user-data px-status
    if px-status not = spaces
        display "harmovela failed: " px-status
        stop run returning 1
    end-if
    compute expected-length = function length(
        function trim(capture-url))
    if capture-url(1:expected-length) not =
        "http://harmovela.test/aep/api/events"
        display "unexpected url: " capture-url(1:expected-length)
        stop run returning 1
    end-if
    move '{"spec_version":"0.2","id":"run-123-1794294000000000000","type":"tool.call","source":"praxo-core","created_at":"2026-11-10T07:00:00.000000000Z","payload":{"name":"echo"}}'
        to expected-json
    compute expected-length = function length(
        function trim(expected-json))
    compute captured-length = function length(
        function trim(capture-body))
    if capture-body(1:captured-length) not =
        expected-json(1:expected-length)
        display "unexpected body: " capture-body(1:captured-length)
        stop run returning 1
    end-if
    if px-harmovela-output(1:px-harmovela-output-length) not =
        expected-json(1:expected-length)
        display "unexpected output: "
            px-harmovela-output(1:px-harmovela-output-length)
        stop run returning 1
    end-if

    move "F" to capture-mode
    call "praxo-harmovela" using px-harmovela-options
        px-harmovela-result px-harmovela-event px-user-data px-status
    if px-status not = "HARMOVELA_HTTP"
        display "expected HTTP error, got: " px-status
        stop run returning 1
    end-if
    display "Harmovela tests passed"
    stop run.
end program harmovela-tests.

identification division.
program-id. fake-harmovela-transport recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
linkage section.
copy "harmovela-call.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-harmovela-call px-user-data px-status.
    move spaces to px-status
    move px-harmovela-url to px-user-data(2:1024)
    move px-harmovela-body to px-user-data(1026:2048)
    if px-user-data(1:1) = "F"
        move 503 to px-harmovela-status-code
    else
        move 204 to px-harmovela-status-code
    end-if
    goback.
end program fake-harmovela-transport.
