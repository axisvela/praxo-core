chunks = ["status: ", "green"]
received = String[]
output = join(chunks)
append!(received, chunks)
@assert output == "status: green"
@assert join(received) == output
println("Julia streaming example passed")
