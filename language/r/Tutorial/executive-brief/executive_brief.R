source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_metrics <- function() {
  list(
    revenue = list(current = 1200, prior = 1000),
    margin = list(current = 0.40, prior = 0.42),
    orders = list(current = 310, prior = 300)
  )
}

fixture_model <- function(period) {
  function(request) {
    tool_messages <- Filter(
      function(item) identical(item$role, roles$tool),
      request$messages
    )
    if (length(tool_messages) > 0L) {
      summary <- json_parse(tool_messages[[length(tool_messages)]]$content)
      return(response(message(
        roles$assistant,
        json_encode(list(brief = summary, causal_claims = list(), actions = list()))
      )))
    }
    response(message(
      roles$assistant,
      "",
      tool_calls = list(tool_call(
        "metrics-1", "summarize_metrics", list(period = period)
      ))
    ))
  }
}

summarize_metrics_tool <- function(state, simulate_failure) {
  list(
    name = "summarize_metrics",
    description = "Compute fixed period deltas and cite metrics; no causal claim.",
    parameters = list(
      type = "object",
      required = list("period"),
      properties = list(period = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$calls <- state$calls + 1L
      if (!identical(arguments$period, "period-100")) {
        stop("unknown period fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated metrics source unavailable")
      }
      metrics <- fixture_metrics()
      list(
        period = "period-100",
        revenue_delta = metrics$revenue$current - metrics$revenue$prior,
        margin_delta = metrics$margin$current - metrics$margin$prior,
        orders_delta = metrics$orders$current - metrics$orders$prior,
        citations = list("metric:revenue", "metric:margin", "metric:orders"),
        association_only = TRUE,
        source = "metrics_fixture"
      )
    }
  )
}

brief_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    return(list(
      allowed = identical(action$toolName, "summarize_metrics") &&
        identical(action$arguments$period, "period-100"),
      reason = "only the fixed period-100 metrics are readable"
    ))
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_case <- function(period = "period-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(period),
      "Summarize fixed metrics with citations and no causal attribution.",
      tools = list(summarize_metrics_tool(state, simulate_failure)),
      allowed_tools = "summarize_metrics",
      policy = brief_policy,
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
  success <- run_case()
  stopifnot(is.null(success$error), identical(success$calls, 1L))
  report <- json_parse(success$output)
  stopifnot(
    as.integer(report$brief$revenue_delta) == 200L,
    abs(report$brief$margin_delta - (-0.02)) < 1e-9,
    as.integer(report$brief$orders_delta) == 10L,
    length(report$brief$citations) == 3L,
    isTRUE(report$brief$association_only),
    length(report$causal_claims) == 0L,
    length(report$actions) == 0L
  )

  denied <- run_case("period-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$calls, 0L)
  )

  failed <- run_case("period-100", TRUE)
  stopifnot(!is.null(failed$error), identical(failed$calls, 1L))

  cat("R executive-brief tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  period <- "period-100"
  index <- match("--period", args)
  if (!is.na(index) && index < length(args)) {
    period <- args[[index + 1L]]
  }
  outcome <- run_case(period, "--simulate-failure" %in% args)
  if (!is.null(outcome$error)) {
    message(sprintf("executive brief failed: reads=%d; %s", outcome$calls, outcome$error$message))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
