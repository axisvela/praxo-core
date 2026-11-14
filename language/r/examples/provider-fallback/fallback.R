run <- function(primary, fallback) {
  tryCatch(
    primary(),
    error = function(primary_error) {
      tryCatch(
        fallback(),
        error = function(unused) stop(primary_error)
      )
    }
  )
}

fallback_calls <- 0
stopifnot(identical(run(function() "primary", function() {
  fallback_calls <<- fallback_calls + 1
  "fallback"
}), "primary"))
stopifnot(fallback_calls == 0)

stopifnot(identical(run(function() stop("MODEL_UNAVAILABLE"), function() "fallback"),
                    "fallback"))

error <- tryCatch(
  {
    run(function() stop("MODEL_UNAVAILABLE"), function() stop("MODEL_UNAVAILABLE"))
    NULL
  },
  error = function(condition) condition
)
stopifnot(!is.null(error), grepl("MODEL_UNAVAILABLE", conditionMessage(error), fixed = TRUE))

cat("R provider fallback example passed\n")
