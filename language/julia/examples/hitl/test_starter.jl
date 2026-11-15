include(joinpath(@__DIR__, "starter.jl"))

output = IOBuffer()
run_example(output)
actual = String(take!(output))
expected = "approve: written; effects=1\nedit: policy rejected; effects=0\n"
actual == expected || error("unexpected output: $(repr(actual))")
println("Julia HITL example test passed")
