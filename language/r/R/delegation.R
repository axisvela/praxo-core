subagent_request <- function(parent_session_id, agent_id, prompt,
                             context = list(), mode = "isolated",
                             history = list()) {
  list(
    parentSessionId = as.character(parent_session_id),
    agentId = as.character(agent_id),
    prompt = as.character(prompt),
    context = as.list(context),
    mode = if (identical(mode, "fork")) "fork" else "isolated",
    history = as.list(history)
  )
}

subagent_result <- function(output = "", task_id = "", agent_id = "",
                            usage = NULL) {
  list(
    taskId = as.character(task_id),
    agentId = as.character(agent_id),
    output = as.character(output),
    usage = usage
  )
}

subagent_run <- function(runner, request) {
  if (!is.function(runner)) {
    praxo_error("SUBAGENT_INVALID", "agent: subagent runner is required")
  }
  if (is.null(request$parentSessionId) || !nzchar(request$parentSessionId)
      || is.null(request$agentId) || !nzchar(request$agentId)) {
    praxo_error("SUBAGENT_INVALID",
                "agent: subagent parent session and agent id are required")
  }
  stamp <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  task <- list(
    id = paste0("subagent-", sprintf("%.0f", as.numeric(Sys.time()) * 1e6)),
    parentSessionId = request$parentSessionId,
    agentId = request$agentId,
    mode = request$mode,
    status = "running",
    output = "",
    error = "",
    createdAt = stamp(),
    updatedAt = stamp()
  )
  outcome <- tryCatch(runner(request), error = function(error) error)
  if (inherits(outcome, "error")) {
    task$status <- "failed"
    task$error <- conditionMessage(outcome)
  } else {
    task$status <- "completed"
    task$output <- outcome$output %||% ""
  }
  task$updatedAt <- stamp()
  task
}
