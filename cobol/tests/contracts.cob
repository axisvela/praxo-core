       >>source format free
identification division.
program-id. cobol-contract-tests.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "toolcall.cpy".
copy "checkpoint.cpy".
copy "schema.cpy".
copy "policy.cpy".
copy "context.cpy".
copy "memory.cpy".
copy "plugin.cpy".
copy "middleware.cpy".
01 assertion-ok pic 9.
01 assertion-label pic x(128).
01 failures binary-long value 0.
01 index-number binary-long.
linkage section.
procedure division.
    perform toolcall-cases
    perform checkpoint-cases
    perform schema-cases
    perform policy-cases
    perform context-cases
    perform memory-cases
    perform plugin-cases
    perform middleware-cases
    if failures = 0
        display "PASS: native COBOL contract boundary cases"
    else
        display "FAIL: " failures " contract assertions"
        move 1 to return-code
    end-if
    goback.
toolcall-cases.
    initialize px-toolcall-request px-toolcall-result
    move "parse" to px-tc-op
    move '<tool_call name="echo">{"text":"hi"}</tool_call>'
        to px-tc-content
    compute px-tc-length = function length(
        function trim(px-tc-content trailing))
    call "praxo-toolcall" using px-toolcall-request px-toolcall-result
    move 1 to assertion-ok
    if px-tc-found not = 1 or px-tc-name(1:4) not = "echo"
        or px-tc-input-length not = 13
        move 0 to assertion-ok
    end-if
    move "toolcall xml" to assertion-label
    perform assert-ok
    initialize px-toolcall-request px-toolcall-result
    move "parse" to px-tc-op
    move '<echo.run>{"x":"}"}  </echo.run>' to px-tc-content
    compute px-tc-length = function length(
        function trim(px-tc-content trailing))
    call "praxo-toolcall" using px-toolcall-request px-toolcall-result
    move 1 to assertion-ok
    if px-tc-found not = 1 or px-tc-name(1:8) not = "echo.run"
        move 0 to assertion-ok
    end-if
    move "toolcall dotted nested" to assertion-label
    perform assert-ok
    initialize px-toolcall-request px-toolcall-result
    move "parse" to px-tc-op
    move 'echo.run {"a":1}' to px-tc-content
    compute px-tc-length = function length(
        function trim(px-tc-content trailing))
    call "praxo-toolcall" using px-toolcall-request px-toolcall-result
    move 1 to assertion-ok
    if px-tc-found not = 1 or px-tc-name(1:8) not = "echo.run"
        move 0 to assertion-ok
    end-if
    move "toolcall plain" to assertion-label
    perform assert-ok
    initialize px-toolcall-request px-toolcall-result
    move "parse" to px-tc-op
    move "plain text" to px-tc-content
    compute px-tc-length = function length(
        function trim(px-tc-content trailing))
    call "praxo-toolcall" using px-toolcall-request px-toolcall-result
    move 1 to assertion-ok
    if px-tc-found not = 0 move 0 to assertion-ok end-if
    move "toolcall invalid" to assertion-label
    perform assert-ok
    initialize px-toolcall-request px-toolcall-result
    move "strip" to px-tc-op
    move 'a<echo.run>{"x":1}</echo.run>b' to px-tc-content
    compute px-tc-length = function length(
        function trim(px-tc-content trailing))
    call "praxo-toolcall" using px-toolcall-request px-toolcall-result
    move 1 to assertion-ok
    if px-tc-text-length not = 2 or px-tc-text(1:2) not = "ab"
        move 0 to assertion-ok
    end-if
    move "toolcall strip dotted" to assertion-label
    perform assert-ok.
checkpoint-cases.
    initialize px-checkpoint-request px-checkpoint-result
    move "register" to px-ck-op
    move "spec.payload" to px-ck-type
    move 12 to px-ck-type-length
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    move 1 to assertion-ok
    if px-ck-error not = spaces move 0 to assertion-ok end-if
    move "checkpoint register" to assertion-label
    perform assert-ok
    move "marshal" to px-ck-op
    move '{"value":"x"}' to px-ck-value
    compute px-ck-value-length = function length(
        function trim(px-ck-value trailing))
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    move 1 to assertion-ok
    if px-ck-error not = spaces or px-ck-output-length < 10
        move 0 to assertion-ok
    end-if
    move "checkpoint marshal" to assertion-label
    perform assert-ok
    move px-ck-output(1:px-ck-output-length) to px-ck-value
    move px-ck-output-length to px-ck-value-length
    move "unmarshal" to px-ck-op
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    move 1 to assertion-ok
    if px-ck-error not = spaces or px-ck-output not = '{"value":"x"}'
        move 0 to assertion-ok
    end-if
    move "checkpoint roundtrip" to assertion-label
    perform assert-ok
    move "marshal" to px-ck-op
    move "spec.missing" to px-ck-type
    move 12 to px-ck-type-length
    move "{}" to px-ck-value
    move 2 to px-ck-value-length
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    move 1 to assertion-ok
    if px-ck-error(1:27) not = "CHECKPOINT_TYPE_NOT_ALLOWED"
        move 0 to assertion-ok
    end-if
    move "checkpoint unregistered" to assertion-label
    perform assert-ok
    move "unmarshal" to px-ck-op
    move '{"type":"spec.missing","data":{}}' to px-ck-value
    compute px-ck-value-length = function length(
        function trim(px-ck-value trailing))
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    move 1 to assertion-ok
    if px-ck-error(1:27) not = "CHECKPOINT_TYPE_NOT_ALLOWED"
        move 0 to assertion-ok
    end-if
    move "checkpoint bad envelope" to assertion-label
    perform assert-ok.
schema-cases.
    initialize px-schema-request px-schema-result
    move '{"type":"array","items":{"type":"integer"}}' to px-sch-schema
    compute px-sch-schema-length = function length(
        function trim(px-sch-schema trailing))
    move '[1,"x"]' to px-sch-data
    compute px-sch-data-length = function length(
        function trim(px-sch-data trailing))
    call "praxo-jsonschema" using px-schema-request px-schema-result
    move 1 to assertion-ok
    if px-sch-error-count not = 1 or px-sch-path(1)(1:4) not = "$[1]"
        move 0 to assertion-ok
    end-if
    move "schema array path" to assertion-label
    perform assert-ok
    move '{"type":"number","enum":[1]}' to px-sch-schema
    compute px-sch-schema-length = function length(
        function trim(px-sch-schema trailing))
    move "1.0" to px-sch-data
    move 3 to px-sch-data-length
    call "praxo-jsonschema" using px-schema-request px-schema-result
    move 1 to assertion-ok
    if px-sch-error-count not = 0 move 0 to assertion-ok end-if
    move "schema numeric enum" to assertion-label
    perform assert-ok
    move '{"type":"string","enum":["x"]}' to px-sch-schema
    compute px-sch-schema-length = function length(
        function trim(px-sch-schema trailing))
    move '"x "' to px-sch-data
    move 4 to px-sch-data-length
    call "praxo-jsonschema" using px-schema-request px-schema-result
    move 1 to assertion-ok
    if px-sch-error-count not = 1 move 0 to assertion-ok end-if
    move "schema string trailing space" to assertion-label
    perform assert-ok
    move '{"type":"string","pattern":"a|b"}' to px-sch-schema
    compute px-sch-schema-length = function length(
        function trim(px-sch-schema trailing))
    move '"a"' to px-sch-data
    move 3 to px-sch-data-length
    call "praxo-jsonschema" using px-schema-request px-schema-result
    move 1 to assertion-ok
    if px-sch-error = spaces move 0 to assertion-ok end-if
    move "schema unsupported pattern" to assertion-label
    perform assert-ok.
policy-cases.
    initialize px-policy-request px-policy-result
    move 1 to px-pol-grant-count
    move "/root" to px-pol-root(1)
    move 5 to px-pol-root-length(1)
    move "read" to px-pol-access(1)
    move 4 to px-pol-access-length(1)
    move "/root/a" to px-pol-target
    move 7 to px-pol-target-length
    move "read" to px-pol-need
    move 4 to px-pol-need-length
    call "praxo-policy" using px-policy-request px-policy-result
    move 1 to assertion-ok
    if px-pol-error not = spaces or px-pol-allowed not = 1
        move 0 to assertion-ok
    end-if
    move "policy absolute root" to assertion-label
    perform assert-ok
    move "root" to px-pol-root(1)
    move 4 to px-pol-root-length(1)
    move "root-evil/x" to px-pol-target
    move 11 to px-pol-target-length
    call "praxo-policy" using px-policy-request px-policy-result
    move 1 to assertion-ok
    if px-pol-allowed not = 0 move 0 to assertion-ok end-if
    move "policy sibling" to assertion-label
    perform assert-ok
    move "root/../outside/x" to px-pol-target
    move 17 to px-pol-target-length
    call "praxo-policy" using px-policy-request px-policy-result
    move 1 to assertion-ok
    if px-pol-allowed not = 0 move 0 to assertion-ok end-if
    move "policy traversal" to assertion-label
    perform assert-ok
    move "C:relative" to px-pol-target
    move 10 to px-pol-target-length
    call "praxo-policy" using px-policy-request px-policy-result
    move 1 to assertion-ok
    if px-pol-error = spaces move 0 to assertion-ok end-if
    move "policy drive relative" to assertion-label
    perform assert-ok.
context-cases.
    initialize px-context-request px-context-result
    move "compact" to px-ctx-op
    move 1 to px-ctx-count
    move "system" to px-ctx-role(1)
    move "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        to px-ctx-content(1)
    move 50 to px-ctx-content-length(1)
    move 2 to px-ctx-max-tokens
    call "praxo-context" using px-context-request px-context-result
    move 1 to assertion-ok
    if px-ctx-ok not = 0 move 0 to assertion-ok end-if
    move "context impossible" to assertion-label
    perform assert-ok
    move 0 to px-ctx-max-tokens
    call "praxo-context" using px-context-request px-context-result
    move 1 to assertion-ok
    if px-ctx-ok not = 1 or px-ctx-out-count not = 1
        move 0 to assertion-ok
    end-if
    move "context disabled" to assertion-label
    perform assert-ok.
memory-cases.
    initialize px-memory-request px-memory-result
    move "clear" to px-mem-op
    call "praxo-memory" using px-memory-request px-memory-result
    move "put" to px-mem-op
    move "s1" to px-mem-session
    move 2 to px-mem-session-length
    move "m1" to px-mem-id
    move 2 to px-mem-id-length
    move "Alpha" to px-mem-content
    move 5 to px-mem-content-length
    move "2026-01-01T00:00:00Z" to px-mem-created
    call "praxo-memory" using px-memory-request px-memory-result
    move "s2" to px-mem-session
    move 2 to px-mem-session-length
    move "m2" to px-mem-id
    move 2 to px-mem-id-length
    move "alpha" to px-mem-content
    move 5 to px-mem-content-length
    move "2026-01-02T00:00:00Z" to px-mem-created
    call "praxo-memory" using px-memory-request px-memory-result
    move "search" to px-mem-op
    move "s2" to px-mem-session
    move 2 to px-mem-session-length
    move "alp" to px-mem-query
    move 3 to px-mem-query-length
    move 10 to px-mem-limit
    call "praxo-memory" using px-memory-request px-memory-result
    move 1 to assertion-ok
    if px-mem-count not = 1 or px-mem-res-id(1)(1:2) not = "m2"
        move 0 to assertion-ok
    end-if
    move "memory isolation substring" to assertion-label
    perform assert-ok.
plugin-cases.
    initialize px-plugin-request px-plugin-result
    move '{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":["a","b","a"],"permissions":{},"limits":{},"health":{},"isolation":"process"}'
        to px-plug-raw
    compute px-plug-length = function length(
        function trim(px-plug-raw trailing))
    call "praxo-plugin" using px-plugin-request px-plugin-result
    move 1 to assertion-ok
    if px-plug-valid not = 0 move 0 to assertion-ok end-if
    move "plugin nested field and duplicate" to assertion-label
    perform assert-ok.
middleware-cases.
    initialize px-middleware-request px-middleware-result
    move "pii" to px-mw-op
    move "a@b.com and c@d.com" to px-mw-text
    compute px-mw-text-length = function length(
        function trim(px-mw-text trailing))
    call "praxo-middleware" using px-middleware-request px-middleware-result
    move 1 to assertion-ok
    if px-mw-result not = "[REDACTED:email] and [REDACTED:email]"
        move 0 to assertion-ok
    end-if
    move "middleware multiple emails" to assertion-label
    perform assert-ok
    move "pii-json" to px-mw-op
    move '{"a":{"b":["x@example.com"]}}' to px-mw-text
    compute px-mw-text-length = function length(
        function trim(px-mw-text trailing))
    call "praxo-middleware" using px-middleware-request px-middleware-result
    move 1 to assertion-ok
    if px-mw-result not = '{"a":{"b":["[REDACTED:email]"]}}'
        move 0 to assertion-ok
    end-if
    move "middleware deep json pii" to assertion-label
    perform assert-ok.
assert-ok.
    if assertion-ok = 0
        add 1 to failures
        display "FAIL: " assertion-label
    end-if.
end program cobol-contract-tests.
