let chunks = ["status: ", "green"]
let output = chunks.joined()
precondition(output == "status: green")
precondition(chunks.joined() == output)
print("Swift streaming example passed")
