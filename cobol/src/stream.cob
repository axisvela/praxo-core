       >>source format free
identification division.
program-id. praxo-stream recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
linkage section.
copy "stream.cpy".
procedure division using px-stream-result.
    move 6 to px-stream-count
    move "values" to px-stream-kind(1)
    move "updates" to px-stream-kind(2)
    move "messages" to px-stream-kind(3)
    move "tasks" to px-stream-kind(4)
    move "debug" to px-stream-kind(5)
    move "checkpoint" to px-stream-kind(6)
    goback.
end program praxo-stream.
