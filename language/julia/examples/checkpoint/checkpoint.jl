push!(LOAD_PATH, "language/julia/src")
using PraxoCore

allow = CheckpointAllowlist()
register!(allow, "order")
value = Json.parse("{\"value\":\"x\"}")
data = marshal(allow, "order", value)
decoded = unmarshal(allow, data)
@assert Json.equals(decoded, value)
println("Julia checkpoint example passed")
