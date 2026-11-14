if (requireNamespace("praxocore", quietly = TRUE)) {
  library(praxocore)
}

turn_model <- function(request) {
  response(message(roles$assistant, paste0("turn ", length(request$messages))))
}

allowlist <- checkpoint_allowlist()
checkpoint_register(allowlist, "session")

session_value <- session("session-1", messages = list(
  message(roles$user, "first"),
  message(roles$assistant, "ack")
))
payload <- checkpoint_marshal(allowlist, "session", list(messages = session_value$messages))

restored <- checkpoint_unmarshal(allowlist, payload)
session_value$messages <- restored$messages
result <- agent_run(turn_model, "second", session = session_value)
stopifnot(identical(result$output, "turn 3"))

session_value$messages <- result$messages
payload <- checkpoint_marshal(allowlist, "session", list(messages = session_value$messages))

restored <- checkpoint_unmarshal(allowlist, payload)
session_value$messages <- restored$messages
result <- agent_run(turn_model, "third", session = session_value)
stopifnot(identical(result$output, "turn 5"))

cat("restored messages: ", length(session_value$messages), "\n", sep = "")
cat("output: ", result$output, "\n", sep = "")
