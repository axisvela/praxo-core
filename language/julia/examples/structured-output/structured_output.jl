push!(LOAD_PATH, "language/julia/src")
using PraxoCore

schema = Json.parse("{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\"}}}")
@assert isempty(JsonSchema.validate(schema, Dict("name" => "ok")))
@assert !isempty(JsonSchema.validate(schema, Dict{String,Any}()))
println("Julia structured output example passed")
