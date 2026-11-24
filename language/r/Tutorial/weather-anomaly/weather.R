source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_series <- function() {
  data.frame(
    day = c(1, 2, 3, 4, 5),
    temp_c = c(20.1, 20.4, 26.0, 20.2, 19.8),
    stringsAsFactors = FALSE
  )
}

fixture_model <- function(region) {
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
          "series-1",
          "analyze_series",
          list(region = region)
        ))
      )))
    }
    if (length(tool_messages) == 1L) {
      return(response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "notice-1",
          "draft_notice",
          list(region = region, action = "draft_notice")
        ))
      )))
    }
    metrics <- json_parse(tool_messages[[1]]$content)
    notice <- json_parse(tool_messages[[2]]$content)
    response(message(
      roles$assistant,
      json_encode(list(
        stage = "weather_notice_drafted",
        metrics = metrics,
        notice = notice,
        forecasts = 0L,
        dispatches = 0L
      ))
    ))
  }
}

analyze_tool <- function(state, simulate_failure) {
  list(
    name = "analyze_series",
    description = "Compute fixed time-series anomalies in native R; no operational forecast.",
    parameters = list(
      type = "object",
      required = list("region"),
      properties = list(region = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$reads <- state$reads + 1L
      if (!identical(arguments$region, "region-100")) {
        stop("unknown region fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated weather series unavailable")
      }
      data <- fixture_series()
      baseline <- median(data$temp_c)
      deviations <- abs(data$temp_c - baseline)
      threshold <- 2.5
      anomalies <- sum(deviations > threshold)
      list(
        region_id = "region-100",
        days = nrow(data),
        baseline_c = baseline,
        max_deviation = round(max(deviations), 1),
        threshold = threshold,
        anomalies = anomalies,
        source = "weather_fixture"
      )
    }
  )
}

draft_tool <- function(state) {
  list(
    name = "draft_notice",
    description = "Draft a review-only anomaly notice; no forecast or disaster dispatch.",
    parameters = list(
      type = "object",
      required = list("region", "action"),
      properties = list(
        region = list(type = "string"),
        action = list(type = "string")
      )
    ),
    invoke = function(arguments) {
      state$drafts <- state$drafts + 1L
      if (!identical(arguments$action, "draft_notice")) {
        stop("unsupported notice action")
      }
      list(
        notice_id = "weather-100",
        region_id = arguments$region,
        action = arguments$action,
        notices = 1L,
        status = "draft_only",
        review_required = TRUE,
        forecasts = 0L,
        dispatches = 0L
      )
    }
  )
}

weather_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    if (identical(action$toolName, "analyze_series")) {
      return(list(
        allowed = identical(action$arguments$region, "region-100"),
        reason = "only the fixed region-100 fixture is readable"
      ))
    }
    if (identical(action$toolName, "draft_notice")) {
      return(list(
        allowed = identical(action$arguments$region, "region-100") &&
          identical(action$arguments$action, "draft_notice"),
        reason = "only a region-100 draft_notice is allowed"
      ))
    }
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_weather <- function(region = "region-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$reads <- 0L
  state$drafts <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(region),
      "Analyze the fixed series and draft a review-only anomaly notice.",
      tools = list(analyze_tool(state, simulate_failure), draft_tool(state)),
      allowed_tools = c("analyze_series", "draft_notice"),
      policy = weather_policy,
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
  success <- run_weather()
  stopifnot(
    is.null(success$error),
    identical(success$reads, 1L),
    identical(success$drafts, 1L)
  )
  report <- json_parse(success$output)
  stopifnot(
    identical(report$stage, "weather_notice_drafted"),
    as.integer(report$metrics$days) == 5L,
    abs(report$metrics$max_deviation - 5.8) < 1e-9,
    as.integer(report$metrics$anomalies) == 1L,
    identical(report$notice$status, "draft_only"),
    isTRUE(report$notice$review_required),
    as.integer(report$forecasts) == 0L,
    as.integer(report$dispatches) == 0L
  )

  denied <- run_weather("region-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$reads, 0L),
    identical(denied$drafts, 0L)
  )

  failed <- run_weather("region-100", TRUE)
  stopifnot(
    !is.null(failed$error),
    identical(failed$reads, 1L),
    identical(failed$drafts, 0L)
  )

  cat("R weather-anomaly tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  region <- "region-100"
  region_index <- match("--region", args)
  if (!is.na(region_index) && region_index < length(args)) {
    region <- args[[region_index + 1L]]
  }
  simulate_failure <- "--simulate-failure" %in% args
  outcome <- run_weather(region, simulate_failure)
  if (!is.null(outcome$error)) {
    message(sprintf(
      "weather anomaly failed: reads=%d drafts=%d; %s",
      outcome$reads, outcome$drafts, outcome$error$message
    ))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
