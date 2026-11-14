function run_retry(failures, max_attempts=3)
    for attempt in 1:max_attempts
        if attempt > failures
            return ("status: green", attempt)
        end
    end
    return (nothing, "MODEL_UNAVAILABLE", max_attempts)
end

recovered = run_retry(2)
@assert recovered[1] == "status: green" && recovered[2] == 3
exhausted = run_retry(3)
@assert exhausted[1] === nothing && exhausted[2] == "MODEL_UNAVAILABLE" && exhausted[3] == 3
println("Julia retry example passed")
