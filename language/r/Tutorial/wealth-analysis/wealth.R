source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_portfolio <- function() {
  data.frame(
    asset = c("equity_fund", "bond_fund", "cash"),
    value = c(60000, 30000, 10000),
    risk = c(0.8, 0.2, 0.0),
    stringsAsFactors = FALSE
  )
}

fixture_model <- function(account) {
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
          "analysis-1",
          "analyze_portfolio",
          list(account = account)
        ))
      )))
    }
    if (length(tool_messages) == 1L) {
      analysis <- json_parse(tool_messages[[1]]$content)
      return(response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "rebalance-1",
          "draft_rebalance",
          list(account = account, action = analysis$recommendation)
        ))
      )))
    }
    analysis <- json_parse(tool_messages[[1]]$content)
    rebalance <- json_parse(tool_messages[[2]]$content)
    response(message(
      roles$assistant,
      json_encode(list(
        analysis = analysis,
        rebalance = rebalance,
        trades_executed = 0L
      ))
    ))
  }
}

analyze_tool <- function(state, simulate_failure) {
  list(
    name = "analyze_portfolio",
    description = "Compute native R portfolio metrics for the fixed fixture; no trades.",
    parameters = list(
      type = "object",
      required = list("account"),
      properties = list(account = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$reads <- state$reads + 1L
      if (!identical(arguments$account, "acct-100")) {
        stop("unknown account fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated portfolio data unavailable")
      }
      data <- fixture_portfolio()
      total <- sum(data$value)
      weights <- data$value / total
      weighted_risk <- sum(weights * data$risk)
      concentration <- max(weights)
      recommendation <- if (weighted_risk > 0.5 || concentration > 0.55) {
        "rebalance"
      } else {
        "hold"
      }
      list(
        account_id = "acct-100",
        total_value = total,
        weighted_risk = round(weighted_risk, 2),
        concentration = round(concentration, 2),
        recommendation = recommendation,
        holdings = lapply(seq_len(nrow(data)), function(index) {
          list(
            asset = data$asset[index],
            weight = round(weights[index], 2)
          )
        })
      )
    }
  )
}

draft_tool <- function(state) {
  list(
    name = "draft_rebalance",
    description = "Draft a review-only rebalance proposal; no trades execute.",
    parameters = list(
      type = "object",
      required = list("account", "action"),
      properties = list(
        account = list(type = "string"),
        action = list(type = "string")
      )
    ),
    invoke = function(arguments) {
      state$drafts <- state$drafts + 1L
      if (!identical(arguments$action, "rebalance")) {
        stop("unsupported rebalance action")
      }
      list(
        account_id = arguments$account,
        action = arguments$action,
        status = "draft_only",
        review_required = TRUE,
        trades_executed = 0L
      )
    }
  )
}

wealth_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    if (identical(action$toolName, "analyze_portfolio")) {
      return(list(
        allowed = identical(action$arguments$account, "acct-100"),
        reason = "only the fixed acct-100 fixture is readable"
      ))
    }
    if (identical(action$toolName, "draft_rebalance")) {
      return(list(
        allowed = identical(action$arguments$account, "acct-100") &&
          identical(action$arguments$action, "rebalance"),
        reason = "only an acct-100 rebalance draft is allowed"
      ))
    }
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_wealth <- function(account = "acct-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$reads <- 0L
  state$drafts <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(account),
      "Analyze the fixed portfolio and draft a review-only rebalance.",
      tools = list(analyze_tool(state, simulate_failure), draft_tool(state)),
      allowed_tools = c("analyze_portfolio", "draft_rebalance"),
      policy = wealth_policy,
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
  success <- run_wealth()
  stopifnot(
    is.null(success$error),
    identical(success$reads, 1L),
    identical(success$drafts, 1L)
  )
  report <- json_parse(success$output)
  stopifnot(
    as.integer(report$analysis$total_value) == 100000L,
    abs(report$analysis$weighted_risk - 0.54) < 1e-9,
    abs(report$analysis$concentration - 0.6) < 1e-9,
    identical(report$analysis$recommendation, "rebalance"),
    length(report$analysis$holdings) == 3L,
    identical(report$rebalance$status, "draft_only"),
    isTRUE(report$rebalance$review_required),
    as.integer(report$rebalance$trades_executed) == 0L,
    as.integer(report$trades_executed) == 0L
  )

  denied <- run_wealth("acct-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$reads, 0L),
    identical(denied$drafts, 0L)
  )

  failed <- run_wealth("acct-100", TRUE)
  stopifnot(
    !is.null(failed$error),
    identical(failed$reads, 1L),
    identical(failed$drafts, 0L)
  )

  cat("R wealth-analysis tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  account <- "acct-100"
  account_index <- match("--account", args)
  if (!is.na(account_index) && account_index < length(args)) {
    account <- args[[account_index + 1L]]
  }
  simulate_failure <- "--simulate-failure" %in% args
  outcome <- run_wealth(account, simulate_failure)
  if (!is.null(outcome$error)) {
    message(sprintf(
      "wealth analysis failed: reads=%d drafts=%d; %s",
      outcome$reads, outcome$drafts, outcome$error$message
    ))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
