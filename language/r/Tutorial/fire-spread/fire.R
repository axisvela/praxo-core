source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_cells <- function() {
  data.frame(
    cell = c("c-1", "c-2", "c-3", "c-4"),
    fuel = c(0.7, 0.6, 0.5, 0.8),
    wind_kmh = c(18, 16, 12, 20),
    slope = c(5, 4, 3, 6),
    stringsAsFactors = FALSE
  )
}

fixture_model <- function(cell) {
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
          "spread-1",
          "analyze_spread",
          list(cell = cell)
        ))
      )))
    }
    if (length(tool_messages) == 1L) {
      return(response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "report-1",
          "draft_spread_report",
          list(cell = cell, action = "draft_spread_report")
        ))
      )))
    }
    metrics <- json_parse(tool_messages[[1]]$content)
    report <- json_parse(tool_messages[[2]]$content)
    response(message(
      roles$assistant,
      json_encode(list(
        stage = "fire_spread_report_drafted",
        metrics = metrics,
        report = report,
        warnings = 0L,
        dispatches = 0L
      ))
    ))
  }
}

analyze_tool <- function(state, simulate_failure) {
  list(
    name = "analyze_spread",
    description = "Compute native R spread indicators for fixed weather/fuel cells; no warning.",
    parameters = list(
      type = "object",
      required = list("cell"),
      properties = list(cell = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$reads <- state$reads + 1L
      if (!identical(arguments$cell, "cell-100")) {
        stop("unknown cell fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated cell data unavailable")
      }
      data <- fixture_cells()
      spread_rate <- round(0.1 * data$fuel * data$wind_kmh + 0.05 * data$slope, 2)
      list(
        cell_id = "cell-100",
        cells = nrow(data),
        wind_kmh = data$wind_kmh[1],
        fuel = data$fuel[1],
        slope = data$slope[1],
        spread_rate = spread_rate[1],
        scenarios = 2L,
        source = "cell_fixture"
      )
    }
  )
}

draft_tool <- function(state) {
  list(
    name = "draft_spread_report",
    description = "Draft a review-only spread report; no operational warning or dispatch.",
    parameters = list(
      type = "object",
      required = list("cell", "action"),
      properties = list(
        cell = list(type = "string"),
        action = list(type = "string")
      )
    ),
    invoke = function(arguments) {
      state$drafts <- state$drafts + 1L
      if (!identical(arguments$action, "draft_spread_report")) {
        stop("unsupported report action")
      }
      list(
        report_id = "fire-100",
        cell_id = arguments$cell,
        action = arguments$action,
        scenarios = 2L,
        spread_rate = 1.51,
        status = "draft_only",
        review_required = TRUE,
        warnings = 0L,
        dispatches = 0L
      )
    }
  )
}

fire_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    if (identical(action$toolName, "analyze_spread")) {
      return(list(
        allowed = identical(action$arguments$cell, "cell-100"),
        reason = "only the fixed cell-100 fixture is readable"
      ))
    }
    if (identical(action$toolName, "draft_spread_report")) {
      return(list(
        allowed = identical(action$arguments$cell, "cell-100") &&
          identical(action$arguments$action, "draft_spread_report"),
        reason = "only a cell-100 draft_spread_report is allowed"
      ))
    }
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_fire <- function(cell = "cell-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$reads <- 0L
  state$drafts <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(cell),
      "Analyze the fixed cells and draft a review-only spread report.",
      tools = list(analyze_tool(state, simulate_failure), draft_tool(state)),
      allowed_tools = c("analyze_spread", "draft_spread_report"),
      policy = fire_policy,
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
  success <- run_fire()
  stopifnot(
    is.null(success$error),
    identical(success$reads, 1L),
    identical(success$drafts, 1L)
  )
  report <- json_parse(success$output)
  stopifnot(
    identical(report$stage, "fire_spread_report_drafted"),
    as.integer(report$metrics$cells) == 4L,
    as.integer(report$metrics$wind_kmh) == 18L,
    abs(report$metrics$spread_rate - 1.51) < 1e-9,
    identical(report$report$status, "draft_only"),
    isTRUE(report$report$review_required),
    as.integer(report$warnings) == 0L,
    as.integer(report$dispatches) == 0L
  )

  denied <- run_fire("cell-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$reads, 0L),
    identical(denied$drafts, 0L)
  )

  failed <- run_fire("cell-100", TRUE)
  stopifnot(
    !is.null(failed$error),
    identical(failed$reads, 1L),
    identical(failed$drafts, 0L)
  )

  cat("R fire-spread tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  cell <- "cell-100"
  cell_index <- match("--cell", args)
  if (!is.na(cell_index) && cell_index < length(args)) {
    cell <- args[[cell_index + 1L]]
  }
  simulate_failure <- "--simulate-failure" %in% args
  outcome <- run_fire(cell, simulate_failure)
  if (!is.null(outcome$error)) {
    message(sprintf(
      "fire spread failed: reads=%d drafts=%d; %s",
      outcome$reads, outcome$drafts, outcome$error$message
    ))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
