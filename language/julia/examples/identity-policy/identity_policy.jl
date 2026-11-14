authorize(tenant, role, active, tool, target) =
    active && role == "operator" && tenant == target && tool == "record"

@assert authorize("acme", "operator", true, "record", "acme")
@assert !authorize("acme", "viewer", true, "record", "acme")
@assert !authorize("acme", "operator", true, "record", "other")
@assert !authorize("acme", "operator", false, "record", "acme")
println("Julia identity policy example passed")
