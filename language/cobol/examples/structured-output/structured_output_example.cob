       >>source format free
identification division.
program-id. structured-output-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "schema.cpy".
procedure division.
    initialize px-schema-request px-schema-result
    move '{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}'
        to px-sch-schema
    compute px-sch-schema-length = function length(
        function trim(px-sch-schema trailing))
    move '{"name":"ok"}' to px-sch-data
    compute px-sch-data-length = function length(
        function trim(px-sch-data trailing))
    call "praxo-jsonschema" using px-schema-request px-schema-result
    if px-sch-error not = spaces or px-sch-error-count not = 0
        display "valid output was rejected"
        stop run returning 1
    end-if

    move "{}" to px-sch-data
    move 2 to px-sch-data-length
    call "praxo-jsonschema" using px-schema-request px-schema-result
    if px-sch-error-count = 0
        display "invalid output was accepted"
        stop run returning 1
    end-if

    display "COBOL structured output example passed"
    stop run.
