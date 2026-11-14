source("language/r/R/json.R")
source("language/r/R/core.R")

chunks <- c("status: ", "green")
received <- character()
streaming <- function(request, on_delta) {
  for (chunk in chunks) on_delta(chunk)
  response(message(roles$assistant, paste0(chunks, collapse = "")))
}
result <- agent_run(
  function(request) response(message(roles$assistant, paste0(chunks, collapse = ""))),
  "Check the status.",
  streaming_model = streaming,
  on_delta = function(delta) received <<- c(received, delta)
)
stopifnot(identical(result$output, "status: green"))
stopifnot(identical(received, chunks))
stopifnot(identical(paste0(received, collapse = ""), result$output))
cat("R streaming example passed\n")
