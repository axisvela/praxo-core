func runRetry(failures: Int, max: Int = 3) -> (String?, Int) {
    for attempt in 1...max {
        if attempt > failures {
            return ("status: green", attempt)
        }
    }
    return (nil, max)
}

let recovered = runRetry(failures: 2)
precondition(recovered.0 == "status: green" && recovered.1 == 3)
let exhausted = runRetry(failures: 3)
precondition(exhausted.0 == nil && exhausted.1 == 3)
print("Swift retry example passed")
