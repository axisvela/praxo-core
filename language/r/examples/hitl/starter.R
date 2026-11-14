if (requireNamespace("praxocore", quietly = TRUE)) {
  library(praxocore)
}

fixture_model <- function() {
  function(request) {
    last <- request$messages[[length(request$messages)]]
    if (identical(last$role, roles$tool)) {
      return(response(message(roles$assistant, "done")))
    }
    response(message(
      roles$assistant,
      "",
      tool_calls = list(tool_call(
        "write-note-1",
        "write_note",
        list(text = "hello", visibility = "public")
      ))
    ))
  }
}

write_note_tool <- function(state) {
  list(
    name = "write_note",
    description = "Write a short note with the requested visibility.",
    parameters = list(
      type = "object",
      required = list("text", "visibility"),
      properties = list(
        text = list(type = "string"),
        visibility = list(type = "string", enum = list("public", "private"))
      )
    ),
    invoke = function(arguments) {
      state$notes <- c(state$notes, arguments$text)
      "written"
    }
  )
}

public_notes_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    return(list(
      allowed = identical(action$toolName, "write_note") &&
        identical(action$arguments$visibility, "public"),
      reason = "only public notes are permitted"
    ))
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_scenario <- function(decision) {
  state <- new.env(parent = emptyenv())
  state$notes <- character()
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(),
      "Write a note.",
      tools = list(write_note_tool(state)),
      allowed_tools = "write_note",
      policy = public_notes_policy,
      interrupt_on = "write_note",
      on_interrupt_decision = function(interrupt) decision,
      max_steps = 3L
    )
    result$output
  }, error = function(caught) {
    error <<- caught
    ""
  })
  list(output = output, effects = length(state$notes), error = error)
}

approved <- run_scenario(interrupt_decision(interrupt_approve))
stopifnot(
  is.null(approved$error),
  identical(approved$output, "done"),
  identical(approved$effects, 1L)
)
cat("approve: written; effects=1\n")

edited <- run_scenario(interrupt_decision(
  interrupt_edit,
  arguments = list(text = "hello", visibility = "private")
))
stopifnot(
  inherits(edited$error, "praxo_error"),
  identical(edited$error$code, "AGENT_POLICY_DENIED"),
  identical(edited$effects, 0L)
)
cat("edit: policy rejected; effects=0\n")
