type Outcome = object
  output: string
  code: string
  calls: int

proc runRetry(failures: int, maxAttempts = 3): Outcome =
  for attempt in 1 .. maxAttempts:
    if attempt > failures:
      return Outcome(output: "status: green", calls: attempt)
  Outcome(code: "MODEL_UNAVAILABLE", calls: maxAttempts)

let recovered = runRetry(2)
doAssert recovered.output == "status: green" and recovered.calls == 3
let exhausted = runRetry(3)
doAssert exhausted.code == "MODEL_UNAVAILABLE" and exhausted.calls == 3
echo "Nim retry example passed"
