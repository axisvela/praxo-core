func runFallback(primaryFails: Bool, fallbackFails: Bool) -> String {
    if !primaryFails { return "primary" }
    if !fallbackFails { return "fallback" }
    return "MODEL_UNAVAILABLE"
}

precondition(runFallback(primaryFails: false, fallbackFails: false) == "primary")
precondition(runFallback(primaryFails: true, fallbackFails: false) == "fallback")
precondition(runFallback(primaryFails: true, fallbackFails: true) == "MODEL_UNAVAILABLE")
print("Swift provider fallback example passed")
