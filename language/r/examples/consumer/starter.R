if (requireNamespace("praxocore", quietly = TRUE)) {
  library(praxocore)
}

fixture_model <- function(target) {
  function(request) {
    last <- request$messages[[length(request$messages)]]
    if (identical(last$role, roles$tool)) {
      return(response(message(roles$assistant, "recorded")))
    }
    response(message(
      roles$assistant,
      "",
      tool_calls = list(tool_call("record-1", "record", list(target = target)))
    ))
  }
}

record_tool <- function(state) {
  list(
    name = "record",
    description = "Record a target in an in-memory counter.",
    parameters = list(
      type = "object",
      required = list("target"),
      properties = list(target = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$calls <- state$calls + 1L
      "recorded"
    }
  )
}

policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    return(list(
      allowed = identical(action$toolName, "record") &&
        identical(action$arguments$target, "public"),
      reason = "only the public target is permitted"
    ))
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_scenario <- function(target) {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(target),
      "Record the requested target.",
      tools = list(record_tool(state)),
      allowed_tools = "record",
      policy = policy,
      max_steps = 3L
    )
    result$output
  }, error = function(caught) {
    error <<- caught
    ""
  })
  list(output = output, calls = state$calls, error = error)
}

allowed <- run_scenario("public")
stopifnot(
  is.null(allowed$error),
  identical(allowed$output, "recorded"),
  identical(allowed$calls, 1L)
)
cat("allow: recorded; effects=1\n")

denied <- run_scenario("private")
stopifnot(
  inherits(denied$error, "praxo_error"),
  identical(denied$error$code, "AGENT_POLICY_DENIED"),
  identical(denied$calls, 0L)
)
cat("deny: policy rejected; effects=0\n")
