source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_site <- function() {
  list(
    footfall = 8000,
    competition = 3,
    units = 10,
    rent_per_unit = 24000,
    lease_cost = 120000,
    value = 1800000
  )
}

fixture_model <- function(site) {
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
          "metrics-1",
          "analyze_site",
          list(site = site)
        ))
      )))
    }
    if (length(tool_messages) == 1L) {
      metrics <- json_parse(tool_messages[[1]]$content)
      return(response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "forecast-1",
          "draft_forecast",
          list(site = site, action = "draft_forecast", forecast_yield = metrics$forecast_yield)
        ))
      )))
    }
    metrics <- json_parse(tool_messages[[1]]$content)
    forecast <- json_parse(tool_messages[[2]]$content)
    response(message(
      roles$assistant,
      json_encode(list(
        stage = "property_forecast_drafted",
        metrics = metrics,
        forecast = forecast,
        probabilities = 0L,
        return_claims = 0L
      ))
    ))
  }
}

analyze_tool <- function(state, simulate_failure) {
  list(
    name = "analyze_site",
    description = "Compute native R site metrics and yield assumptions; no profiling.",
    parameters = list(
      type = "object",
      required = list("site"),
      properties = list(site = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$reads <- state$reads + 1L
      if (!identical(arguments$site, "site-100")) {
        stop("unknown site fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated site data unavailable")
      }
      data <- fixture_site()
      gross_rent <- data$units * data$rent_per_unit
      net_income <- gross_rent - data$lease_cost
      forecast_yield <- round(net_income / data$value, 3)
      list(
        site_id = "site-100",
        footfall = data$footfall,
        competition = data$competition,
        gross_rent = gross_rent,
        net_income = net_income,
        value = data$value,
        forecast_yield = forecast_yield,
        scenarios = 2L,
        assumptions = list("footfall stable", "rent fixed", "no vacancy"),
        source = "site_fixture"
      )
    }
  )
}

draft_tool <- function(state) {
  list(
    name = "draft_forecast",
    description = "Draft a review-only forecast with stated assumptions; no probability claim.",
    parameters = list(
      type = "object",
      required = list("site", "action"),
      properties = list(
        site = list(type = "string"),
        action = list(type = "string"),
        forecast_yield = list(type = "number")
      )
    ),
    invoke = function(arguments) {
      state$drafts <- state$drafts + 1L
      if (!identical(arguments$action, "draft_forecast")) {
        stop("unsupported forecast action")
      }
      list(
        forecast_id = "property-100",
        site_id = arguments$site,
        action = arguments$action,
        scenarios = 2L,
        forecast_yield = 0.067,
        status = "draft_only",
        review_required = TRUE,
        probabilities = 0L,
        return_claims = 0L
      )
    }
  )
}

property_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    if (identical(action$toolName, "analyze_site")) {
      return(list(
        allowed = identical(action$arguments$site, "site-100"),
        reason = "only the fixed site-100 fixture is readable"
      ))
    }
    if (identical(action$toolName, "draft_forecast")) {
      return(list(
        allowed = identical(action$arguments$site, "site-100") &&
          identical(action$arguments$action, "draft_forecast"),
        reason = "only a site-100 draft_forecast is allowed"
      ))
    }
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_property <- function(site = "site-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$reads <- 0L
  state$drafts <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(site),
      "Analyze the fixed site metrics and draft a review-only forecast.",
      tools = list(analyze_tool(state, simulate_failure), draft_tool(state)),
      allowed_tools = c("analyze_site", "draft_forecast"),
      policy = property_policy,
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
  success <- run_property()
  stopifnot(
    is.null(success$error),
    identical(success$reads, 1L),
    identical(success$drafts, 1L)
  )
  report <- json_parse(success$output)
  stopifnot(
    identical(report$stage, "property_forecast_drafted"),
    as.integer(report$metrics$gross_rent) == 240000L,
    as.integer(report$metrics$net_income) == 120000L,
    as.integer(report$metrics$footfall) == 8000L,
    abs(report$metrics$forecast_yield - 0.067) < 1e-9,
    identical(report$metrics$assumptions[[1]], "footfall stable"),
    identical(report$forecast$status, "draft_only"),
    isTRUE(report$forecast$review_required),
    as.integer(report$probabilities) == 0L,
    as.integer(report$return_claims) == 0L
  )

  denied <- run_property("site-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$reads, 0L),
    identical(denied$drafts, 0L)
  )

  failed <- run_property("site-100", TRUE)
  stopifnot(
    !is.null(failed$error),
    identical(failed$reads, 1L),
    identical(failed$drafts, 0L)
  )

  cat("R property-forecast tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  site <- "site-100"
  site_index <- match("--site", args)
  if (!is.na(site_index) && site_index < length(args)) {
    site <- args[[site_index + 1L]]
  }
  simulate_failure <- "--simulate-failure" %in% args
  outcome <- run_property(site, simulate_failure)
  if (!is.null(outcome$error)) {
    message(sprintf(
      "property forecast failed: reads=%d drafts=%d; %s",
      outcome$reads, outcome$drafts, outcome$error$message
    ))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
