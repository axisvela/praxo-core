       >>source format free
identification division.
program-id. service-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 request-method pic x(8).
01 request-path pic x(32).
01 request-principal pic x(64).
01 request-body pic x(256).
01 response-status binary-long.
01 response-body pic x(128).
procedure division.
    move "GET" to request-method
    move "/healthz" to request-path
    move spaces to request-principal
    move spaces to request-body
    perform handle-request
    if response-status not = 200
        display "health failed"
        stop run returning 1
    end-if

    move "POST" to request-method
    move "/run" to request-path
    move spaces to request-principal
    move '{"prompt":"hi"}' to request-body
    perform handle-request
    if response-status not = 401
        display "missing principal was accepted"
        stop run returning 1
    end-if

    move "user-1" to request-principal
    perform handle-request
    if response-status not = 200
        or response-body(1:35) not = '{"output":"hello from the service"}'
        display "run failed"
        stop run returning 1
    end-if

    display "COBOL service example passed"
    stop run.

handle-request.
    move 404 to response-status
    move '{"error":"not found"}' to response-body
    if request-method = "GET" and request-path = "/healthz"
        move 200 to response-status
        move '{"status":"ok"}' to response-body
        exit paragraph
    end-if
    if request-method not = "POST" or request-path not = "/run"
        exit paragraph
    end-if
    if request-principal = spaces
        move 401 to response-status
        move '{"error":"missing X-Praxo-Principal"}' to response-body
        exit paragraph
    end-if
    if request-body(1:10) not = '{"prompt":'
        move 400 to response-status
        move '{"error":"prompt is required"}' to response-body
        exit paragraph
    end-if
    move 200 to response-status
    move '{"output":"hello from the service"}' to response-body.
