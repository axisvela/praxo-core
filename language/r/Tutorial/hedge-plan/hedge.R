source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_farm <- function() {
  data.frame(
    crop = c("wheat", "corn"),
    hectares = c(100, 80),
    price = c(200, 180),
    cost_per_ha = c(150, 140),
    stringsAsFactors = FALSE
  )
}

fixture_model <- function(farm) {
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
          "exposure-1",
          "analyze_exposure",
          list(farm = farm)
        ))
      )))
    }
    if (length(tool_messages) == 1L) {
      exposure <- json_parse(tool_messages[[1]]$content)
      return(response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "plan-1",
          "draft_hedge_plan",
          list(farm = farm, action = "draft_hedge_plan", margin = exposure$margin)
        ))
      )))
    }
    exposure <- json_parse(tool_messages[[1]]$content)
    plan <- json_parse(tool_messages[[2]]$content)
    response(message(
      roles$assistant,
      json_encode(list(
        stage = "hedge_plan_drafted",
        exposure = exposure,
        plan = plan,
        orders = 0L,
        advice = 0L
      ))
    ))
  }
}

analyze_tool <- function(state, simulate_failure) {
  list(
    name = "analyze_exposure",
    description = "Compute native R exposure and scenario margins for the fixed farm; no orders.",
    parameters = list(
      type = "object",
      required = list("farm"),
      properties = list(farm = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$reads <- state$reads + 1L
      if (!identical(arguments$farm, "farm-100")) {
        stop("unknown farm fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated farm data unavailable")
      }
      data <- fixture_farm()
      gross <- sum(data$hectares * data$price)
      cost <- sum(data$hectares * data$cost_per_ha)
      margin <- gross - cost
      downside_margin <- round(gross * 0.9) - cost
      list(
        farm_id = "farm-100",
        gross = gross,
        cost = cost,
        margin = margin,
        downside_margin = downside_margin,
        scenarios = 2L,
        source = "farm_fixture"
      )
    }
  )
}

draft_tool <- function(state) {
  list(
    name = "draft_hedge_plan",
    description = "Draft a review-only hedging plan; never places orders or gives advice.",
    parameters = list(
      type = "object",
      required = list("farm", "action"),
      properties = list(
        farm = list(type = "string"),
        action = list(type = "string"),
        margin = list(type = "number")
      )
    ),
    invoke = function(arguments) {
      state$drafts <- state$drafts + 1L
      if (!identical(arguments$action, "draft_hedge_plan")) {
        stop("unsupported plan action")
      }
      list(
        plan_id = "hedge-100",
        farm_id = arguments$farm,
        action = arguments$action,
        scenarios = 2L,
        downside_margin = 4760L,
        status = "draft_only",
        review_required = TRUE,
        orders = 0L,
        advice = 0L
      )
    }
  )
}

hedge_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    if (identical(action$toolName, "analyze_exposure")) {
      return(list(
        allowed = identical(action$arguments$farm, "farm-100"),
        reason = "only the fixed farm-100 fixture is readable"
      ))
    }
    if (identical(action$toolName, "draft_hedge_plan")) {
      return(list(
        allowed = identical(action$arguments$farm, "farm-100") &&
          identical(action$arguments$action, "draft_hedge_plan"),
        reason = "only a farm-100 draft_hedge_plan is allowed"
      ))
    }
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_hedge <- function(farm = "farm-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$reads <- 0L
  state$drafts <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(farm),
      "Analyze the fixed farm exposure and draft a review-only hedge plan.",
      tools = list(analyze_tool(state, simulate_failure), draft_tool(state)),
      allowed_tools = c("analyze_exposure", "draft_hedge_plan"),
      policy = hedge_policy,
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
  success <- run_hedge()
  stopifnot(
    is.null(success$error),
    identical(success$reads, 1L),
    identical(success$drafts, 1L)
  )
  report <- json_parse(success$output)
  stopifnot(
    identical(report$stage, "hedge_plan_drafted"),
    as.integer(report$exposure$gross) == 34400L,
    as.integer(report$exposure$cost) == 26200L,
    as.integer(report$exposure$margin) == 8200L,
    as.integer(report$exposure$downside_margin) == 4760L,
    identical(report$plan$status, "draft_only"),
    isTRUE(report$plan$review_required),
    as.integer(report$plan$orders) == 0L,
    as.integer(report$orders) == 0L,
    as.integer(report$advice) == 0L
  )

  denied <- run_hedge("farm-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$reads, 0L),
    identical(denied$drafts, 0L)
  )

  failed <- run_hedge("farm-100", TRUE)
  stopifnot(
    !is.null(failed$error),
    identical(failed$reads, 1L),
    identical(failed$drafts, 0L)
  )

  cat("R hedge-plan tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  farm <- "farm-100"
  farm_index <- match("--farm", args)
  if (!is.na(farm_index) && farm_index < length(args)) {
    farm <- args[[farm_index + 1L]]
  }
  simulate_failure <- "--simulate-failure" %in% args
  outcome <- run_hedge(farm, simulate_failure)
  if (!is.null(outcome$error)) {
    message(sprintf(
      "hedge plan failed: reads=%d drafts=%d; %s",
      outcome$reads, outcome$drafts, outcome$error$message
    ))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
