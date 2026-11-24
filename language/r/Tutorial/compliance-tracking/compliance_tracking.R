source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_policies <- function() {
  list(
    prior = list(
      id = "policy-100-v1",
      controls = c("access_review", "logging", "encryption")
    ),
    current = list(
      id = "policy-100-v2",
      controls = c("access_review", "logging", "key_rotation")
    )
  )
}

fixture_model <- function(policy) {
  function(request) {
    tool_messages <- Filter(
      function(item) identical(item$role, roles$tool),
      request$messages
    )
    if (length(tool_messages) > 0L) {
      summary <- json_parse(tool_messages[[length(tool_messages)]]$content)
      return(response(message(
        roles$assistant,
        json_encode(list(compliance = summary, submissions = list()))
      )))
    }
    response(message(
      roles$assistant,
      "",
      tool_calls = list(tool_call(
        "compare-1", "compare_policies", list(policy = policy)
      ))
    ))
  }
}

compare_policies_tool <- function(state, simulate_failure) {
  list(
    name = "compare_policies",
    description = "Compare fixed policy versions and draft review-only remediation.",
    parameters = list(
      type = "object",
      required = list("policy"),
      properties = list(policy = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$calls <- state$calls + 1L
      if (!identical(arguments$policy, "policy-100")) {
        stop("unknown policy fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated policy repository unavailable")
      }
      policies <- fixture_policies()
      removed <- setdiff(policies$prior$controls, policies$current$controls)
      added <- setdiff(policies$current$controls, policies$prior$controls)
      list(
        policy = "policy-100",
        prior_version = policies$prior$id,
        current_version = policies$current$id,
        changed_controls = length(removed) + length(added),
        removed = as.list(removed),
        added = as.list(added),
        missing_controls = 1,
        remediation = list(
          remediation_id = "remediation-100",
          status = "draft_only",
          review_required = TRUE,
          submissions = 0
        ),
        source = "policy_fixture"
      )
    }
  )
}

compliance_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    return(list(
      allowed = identical(action$toolName, "compare_policies") &&
        identical(action$arguments$policy, "policy-100"),
      reason = "only the fixed policy-100 versions are readable"
    ))
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_case <- function(policy = "policy-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(policy),
      "Compare fixed policy versions and draft review-only remediation.",
      tools = list(compare_policies_tool(state, simulate_failure)),
      allowed_tools = "compare_policies",
      policy = compliance_policy,
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
    as.integer(report$compliance$changed_controls) == 2L,
    as.integer(report$compliance$missing_controls) == 1L,
    identical(report$compliance$current_version, "policy-100-v2"),
    identical(report$compliance$remediation$status, "draft_only"),
    isTRUE(report$compliance$remediation$review_required),
    as.integer(report$compliance$remediation$submissions) == 0L
  )

  denied <- run_case("policy-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$calls, 0L)
  )

  failed <- run_case("policy-100", TRUE)
  stopifnot(!is.null(failed$error), identical(failed$calls, 1L))

  cat("R compliance-tracking tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  policy <- "policy-100"
  index <- match("--policy", args)
  if (!is.na(index) && index < length(args)) {
    policy <- args[[index + 1L]]
  }
  outcome <- run_case(policy, "--simulate-failure" %in% args)
  if (!is.null(outcome$error)) {
    message(sprintf("compliance tracking failed: reads=%d; %s", outcome$calls, outcome$error$message))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
