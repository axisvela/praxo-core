run <- function(failures, max_attempts = 3) {
  for (attempt in seq_len(max_attempts)) {
    if (attempt > failures) {
      return(list(status = "ok", output = "status: green", calls = attempt))
    }
  }
  list(status = "error", code = "MODEL_UNAVAILABLE", calls = max_attempts)
}

recovered <- run(2)
stopifnot(recovered$status == "ok", recovered$calls == 3)
exhausted <- run(3)
stopifnot(exhausted$status == "error", exhausted$code == "MODEL_UNAVAILABLE",
          exhausted$calls == 3)

cat("R retry example passed\n")
