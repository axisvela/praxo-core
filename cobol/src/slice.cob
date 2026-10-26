       >>source format free
identification division.
program-id. praxo-json-slice recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
linkage section.
copy "slice.cpy".
procedure division using px-slice-request px-slice-result.
    initialize px-slice-result
    if px-slice-source-length < 1 or > 32768
        or px-slice-start < 1
        or px-slice-size < 1
        or px-slice-start + px-slice-size - 1 > px-slice-source-length
        move "JSON_INVALID" to px-slice-error
        goback
    end-if
    move px-slice-source(px-slice-start:px-slice-size)
        to px-slice-output
    move px-slice-size to px-slice-output-length
    goback.
end program praxo-json-slice.
