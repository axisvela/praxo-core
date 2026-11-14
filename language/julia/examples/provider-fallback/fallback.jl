function run_fallback(primary_fails, fallback_fails)
    !primary_fails && return "primary"
    !fallback_fails && return "fallback"
    return "MODEL_UNAVAILABLE"
end

@assert run_fallback(false, false) == "primary"
@assert run_fallback(true, false) == "fallback"
@assert run_fallback(true, true) == "MODEL_UNAVAILABLE"
println("Julia provider fallback example passed")
