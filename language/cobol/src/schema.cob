       >>source format free
identification division.
program-id. praxo-jsonschema recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 visit-request.
   05 visit-schema pic x(32768).
   05 visit-schema-length binary-long.
   05 visit-data pic x(32768).
   05 visit-data-length binary-long.
   05 visit-path pic x(256).
   05 visit-path-length binary-long.
linkage section.
copy "schema.cpy".
procedure division using px-schema-request px-schema-result.
    initialize px-schema-result
    if px-sch-schema-length < 1 or > 32768
        or px-sch-data-length < 1 or > 32768
        move "INVALID_REQUEST" to px-sch-error
        goback
    end-if
    move px-sch-schema(1:px-sch-schema-length) to visit-schema
    move px-sch-schema-length to visit-schema-length
    move px-sch-data(1:px-sch-data-length) to visit-data
    move px-sch-data-length to visit-data-length
    move "$" to visit-path
    move 1 to visit-path-length
    call "praxo-schema-visit" using visit-request px-schema-result
    goback.
end program praxo-jsonschema.
