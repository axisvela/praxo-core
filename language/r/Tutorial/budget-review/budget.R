source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_program <- function() {
  data.frame(
    item = c("capital", "operations", "grants"),
    budget = c(500000, 300000, 200000),
    disbursed = c(420000, 260000, 140000),
    stringsAsFactors = FALSE
  )
}

fixture_model <- function(program) {
  function(request) {
    tool_messages <- Filter(
      function(item) identical(item$role, roles$tool),
      request$messages
    )
    if (length(tool_messages) == 0L) {
      return(response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "execution-1",
          "analyze_execution",
          list(program = program)
        ))
      )))
    }
    if (length(tool_messages) == 1L) {
      return(response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "review-1",
          "draft_review",
          list(program = program, action = "draft_finding")
        ))
      )))
    }
    execution <- json_parse(tool_messages[[1]]$content)
    review <- json_parse(tool_messages[[2]]$content)
    response(message(
      roles$assistant,
      json_encode(list(
        stage = "budget_review_drafted",
        execution = execution,
        review = review,
        audit_conclusions = 0L
      ))
    ))
  }
}

analyze_tool <- function(state, simulate_failure) {
  list(
    name = "analyze_execution",
    description = "Compute native R budget execution for the fixed fixture; no audit conclusion.",
    parameters = list(
      type = "object",
      required = list("program"),
      properties = list(program = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$reads <- state$reads + 1L
      if (!identical(arguments$program, "program-100")) {
        stop("unknown program fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated budget data unavailable")
      }
      data <- fixture_program()
      budget <- sum(data$budget)
      disbursed <- sum(data$disbursed)
      execution_pct <- round(100 * disbursed / budget, 1)
      variance_pct <- round(100 - execution_pct, 1)
      list(
        program_id = "program-100",
        budget = budget,
        disbursed = disbursed,
        execution_pct = execution_pct,
        variance_pct = variance_pct,
        milestones = 4L,
        completed = 3L,
        flags = if (variance_pct >= 10) list("underspend") else list(),
        source = "budget_fixture"
      )
    }
  )
}

draft_tool <- function(state) {
  list(
    name = "draft_review",
    description = "Draft a review-only performance finding; no official audit conclusion.",
    parameters = list(
      type = "object",
      required = list("program", "action"),
      properties = list(
        program = list(type = "string"),
        action = list(type = "string")
      )
    ),
    invoke = function(arguments) {
      state$drafts <- state$drafts + 1L
      if (!identical(arguments$action, "draft_finding")) {
        stop("unsupported review action")
      }
      list(
        review_id = "budget-review-100",
        program_id = arguments$program,
        action = arguments$action,
        findings = 2L,
        status = "draft_only",
        review_required = TRUE,
        audit_conclusions = 0L
      )
    }
  )
}

budget_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    if (identical(action$toolName, "analyze_execution")) {
      return(list(
        allowed = identical(action$arguments$program, "program-100"),
        reason = "only the fixed program-100 fixture is readable"
      ))
    }
    if (identical(action$toolName, "draft_review")) {
      return(list(
        allowed = identical(action$arguments$program, "program-100") &&
          identical(action$arguments$action, "draft_finding"),
        reason = "only a program-100 draft_finding is allowed"
      ))
    }
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_budget <- function(program = "program-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$reads <- 0L
  state$drafts <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(program),
      "Analyze the fixed budget execution and draft a review-only finding.",
      tools = list(analyze_tool(state, simulate_failure), draft_tool(state)),
      allowed_tools = c("analyze_execution", "draft_review"),
      policy = budget_policy,
      max_steps = 4L
    )
    result$output
  }, error = function(caught) {
    error <<- caught
    ""
  })
  list(output = output, reads = state$reads, drafts = state$drafts, error = error)
}

run_tests <- function() {
  success <- run_budget()
  stopifnot(
    is.null(success$error),
    identical(success$reads, 1L),
    identical(success$drafts, 1L)
  )
  report <- json_parse(success$output)
  stopifnot(
    identical(report$stage, "budget_review_drafted"),
    as.integer(report$execution$budget) == 1000000L,
    as.integer(report$execution$disbursed) == 820000L,
    abs(report$execution$execution_pct - 82) < 1e-9,
    abs(report$execution$variance_pct - 18) < 1e-9,
    as.integer(report$execution$milestones) == 4L,
    as.integer(report$execution$completed) == 3L,
    identical(report$execution$flags[[1]], "underspend"),
    as.integer(report$review$findings) == 2L,
    identical(report$review$status, "draft_only"),
    isTRUE(report$review$review_required),
    as.integer(report$review$audit_conclusions) == 0L,
    as.integer(report$audit_conclusions) == 0L
  )

  denied <- run_budget("program-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$reads, 0L),
    identical(denied$drafts, 0L)
  )

  failed <- run_budget("program-100", TRUE)
  stopifnot(
    !is.null(failed$error),
    identical(failed$reads, 1L),
    identical(failed$drafts, 0L)
  )

  cat("R budget-review tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  program <- "program-100"
  program_index <- match("--program", args)
  if (!is.na(program_index) && program_index < length(args)) {
    program <- args[[program_index + 1L]]
  }
  simulate_failure <- "--simulate-failure" %in% args
  outcome <- run_budget(program, simulate_failure)
  if (!is.null(outcome$error)) {
    message(sprintf(
      "budget review failed: reads=%d drafts=%d; %s",
      outcome$reads, outcome$drafts, outcome$error$message
    ))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
