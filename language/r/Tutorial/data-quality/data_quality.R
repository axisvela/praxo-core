source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_data <- function() {
  data.frame(
    id = 1:6,
    region = c("north", "north", "south", "south", "east", "west"),
    amount = c(100, 120, NA, 90, 200, 80),
    score = c(0.80, 0.90, 0.70, 0.60, 0.95, 0.50),
    stringsAsFactors = FALSE
  )
}

fixture_model <- function(dataset_name) {
  function(request) {
    tool_messages <- Filter(
      function(item) identical(item$role, roles$tool),
      request$messages
    )
    if (length(tool_messages) > 0L) {
      summary <- json_parse(tool_messages[[length(tool_messages)]]$content)
      return(response(message(
        roles$assistant,
        json_encode(list(data_quality = summary, mutating_actions = list()))
      )))
    }
    response(message(
      roles$assistant,
      "",
      tool_calls = list(tool_call(
        "data-1",
        "summarize_dataset",
        list(name = dataset_name)
      ))
    ))
  }
}

summarize_dataset_tool <- function(state, simulate_failure) {
  list(
    name = "summarize_dataset",
    description = "Compute quality statistics for the fixed tutorial dataset; no writes.",
    parameters = list(
      type = "object",
      required = list("name"),
      properties = list(name = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$calls <- state$calls + 1L
      if (!identical(arguments$name, "fixture")) {
        stop("unknown dataset fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated data dependency unavailable")
      }
      data <- fixture_data()
      list(
        source = "fixture",
        rows = nrow(data),
        missing_amount = sum(is.na(data$amount)),
        complete_rows = sum(stats::complete.cases(data)),
        mean_amount = mean(data$amount, na.rm = TRUE),
        max_score = max(data$score, na.rm = TRUE),
        regions = length(unique(data$region))
      )
    }
  )
}

quality_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    return(list(
      allowed = identical(action$toolName, "summarize_dataset") &&
        identical(action$arguments$name, "fixture"),
      reason = "only the fixed fixture dataset is readable"
    ))
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_quality <- function(dataset_name = "fixture", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(dataset_name),
      "Assess the fixed dataset and report computed evidence only.",
      tools = list(summarize_dataset_tool(state, simulate_failure)),
      allowed_tools = "summarize_dataset",
      policy = quality_policy,
      max_steps = 3L
    )
    result$output
  }, error = function(caught) {
    error <<- caught
    ""
  })
  list(output = output, calls = state$calls, error = error)
}

run_tests <- function() {
  success <- run_quality()
  stopifnot(is.null(success$error), identical(success$calls, 1L))
  report <- json_parse(success$output)
  stopifnot(
    as.integer(report$data_quality$rows) == 6L,
    as.integer(report$data_quality$missing_amount) == 1L,
    as.integer(report$data_quality$complete_rows) == 5L,
    as.integer(report$data_quality$regions) == 4L,
    abs(report$data_quality$mean_amount - 118) < 1e-9,
    length(report$mutating_actions) == 0L
  )

  denied <- run_quality("other")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$calls, 0L)
  )

  failed <- run_quality("fixture", TRUE)
  stopifnot(!is.null(failed$error), identical(failed$calls, 1L))

  cat("R data-quality tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  dataset_name <- "fixture"
  dataset_index <- match("--dataset", args)
  if (!is.na(dataset_index) && dataset_index < length(args)) {
    dataset_name <- args[[dataset_index + 1L]]
  }
  simulate_failure <- "--simulate-failure" %in% args
  outcome <- run_quality(dataset_name, simulate_failure)
  if (!is.null(outcome$error)) {
    message(sprintf("data quality failed: reads=%d; %s", outcome$calls, outcome$error$message))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
