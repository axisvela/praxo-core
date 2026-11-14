let chunks = @["status: ", "green"]
let output = chunks.join()
doAssert output == "status: green"
doAssert chunks.join() == output
echo "Nim streaming example passed"
