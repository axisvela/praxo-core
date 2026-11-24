source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_records <- function() {
  data.frame(
    sensor = c("sensor-north", "sensor-east", "sensor-south"),
    pm25 = c(48, 35, 22),
    wind_deg = c(270, 270, 180),
    stringsAsFactors = FALSE
  )
}

fixture_model <- function(site) {
  function(request) {
    tool_messages <- Filter(
      function(item) identical(item$role, roles$tool),
      request$messages
    )
    if (length(tool_messages) > 0L) {
      analysis <- json_parse(tool_messages[[length(tool_messages)]]$content)
      return(response(message(
        roles$assistant,
        json_encode(list(tracing = analysis, enforcement_findings = list()))
      )))
    }
    response(message(
      roles$assistant,
      "",
      tool_calls = list(tool_call(
        "records-1", "analyze_records", list(site = site)
      ))
    ))
  }
}

analyze_records_tool <- function(state, simulate_failure) {
  list(
    name = "analyze_records",
    description = "Compare fixed sensor and wind records; hypotheses only.",
    parameters = list(
      type = "object",
      required = list("site"),
      properties = list(site = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$calls <- state$calls + 1L
      if (!identical(arguments$site, "site-100")) {
        stop("unknown site fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated sensor records unavailable")
      }
      records <- fixture_records()
      list(
        site = "site-100",
        sensors = nrow(records),
        peak_sensor = "sensor-north",
        peak_pm25 = max(records$pm25),
        wind_from_deg = 270,
        hypotheses = list(
          "upwind industrial source near sensor-north",
          "traffic corridor contribution near sensor-east"
        ),
        confidence_claimed = FALSE,
        enforcement_findings = 0,
        source = "sensor_fixture"
      )
    }
  )
}

tracing_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    return(list(
      allowed = identical(action$toolName, "analyze_records") &&
        identical(action$arguments$site, "site-100"),
      reason = "only fixed site-100 records are readable"
    ))
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_case <- function(site = "site-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(site),
      "Compare fixed records and draft investigation hypotheses.",
      tools = list(analyze_records_tool(state, simulate_failure)),
      allowed_tools = "analyze_records",
      policy = tracing_policy,
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
    as.integer(report$tracing$sensors) == 3L,
    identical(report$tracing$peak_sensor, "sensor-north"),
    as.integer(report$tracing$peak_pm25) == 48L,
    length(report$tracing$hypotheses) == 2L,
    identical(report$tracing$confidence_claimed, FALSE),
    as.integer(report$tracing$enforcement_findings) == 0L,
    length(report$enforcement_findings) == 0L
  )

  denied <- run_case("site-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$calls, 0L)
  )

  failed <- run_case("site-100", TRUE)
  stopifnot(!is.null(failed$error), identical(failed$calls, 1L))

  cat("R pollution-tracing tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  site <- "site-100"
  index <- match("--site", args)
  if (!is.na(index) && index < length(args)) {
    site <- args[[index + 1L]]
  }
  outcome <- run_case(site, "--simulate-failure" %in% args)
  if (!is.null(outcome$error)) {
    message(sprintf("pollution tracing failed: reads=%d; %s", outcome$calls, outcome$error$message))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
