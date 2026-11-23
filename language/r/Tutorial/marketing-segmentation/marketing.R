source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_customers <- function() {
  data.frame(
    id = 1:8,
    segment = c("loyal", "loyal", "new", "new", "vip", "vip", "dormant", "dormant"),
    spend = c(320, 280, 90, 60, 900, 750, 40, 25),
    consent = c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
}

fixture_model <- function(dataset_name) {
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
          "segment-1",
          "segment_customers",
          list(dataset = dataset_name)
        ))
      )))
    }
    if (length(tool_messages) == 1L) {
      summary <- json_parse(tool_messages[[1]]$content)
      return(response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "campaign-1",
          "draft_campaign",
          list(segment = summary$top_segment, action = "invite_segment")
        ))
      )))
    }
    summary <- json_parse(tool_messages[[1]]$content)
    draft <- json_parse(tool_messages[[2]]$content)
    response(message(
      roles$assistant,
      json_encode(list(
        segmentation = summary,
        campaign = draft,
        mutating_actions = list()
      ))
    ))
  }
}

segment_tool <- function(state, simulate_failure) {
  list(
    name = "segment_customers",
    description = "Segment the fixed customer fixture and compute native R statistics; no writes.",
    parameters = list(
      type = "object",
      required = list("dataset"),
      properties = list(dataset = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$reads <- state$reads + 1L
      if (!identical(arguments$dataset, "fixture")) {
        stop("unknown dataset fixture")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated customer data unavailable")
      }
      data <- fixture_customers()
      groups <- split(data, data$segment)
      segments <- lapply(names(groups), function(name) {
        rows <- groups[[name]]
        list(
          segment = name,
          customers = nrow(rows),
          average_spend = mean(rows$spend)
        )
      })
      averages <- vapply(segments, function(item) item$average_spend, numeric(1))
      list(
        dataset = "fixture",
        customers = nrow(data),
        consented = sum(data$consent),
        top_segment = segments[[which.max(averages)]]$segment,
        segments = segments
      )
    }
  )
}

draft_tool <- function(state) {
  list(
    name = "draft_campaign",
    description = "Draft a review-only campaign for one segment; no sends.",
    parameters = list(
      type = "object",
      required = list("segment", "action"),
      properties = list(
        segment = list(type = "string"),
        action = list(type = "string")
      )
    ),
    invoke = function(arguments) {
      state$drafts <- state$drafts + 1L
      if (!identical(arguments$action, "invite_segment")) {
        stop("unsupported campaign action")
      }
      list(
        segment = arguments$segment,
        action = arguments$action,
        status = "draft_only",
        review_required = TRUE,
        messages_sent = 0L
      )
    }
  )
}

marketing_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    if (identical(action$toolName, "segment_customers")) {
      return(list(
        allowed = identical(action$arguments$dataset, "fixture"),
        reason = "only the fixed fixture dataset is readable"
      ))
    }
    if (identical(action$toolName, "draft_campaign")) {
      return(list(
        allowed = identical(action$arguments$segment, "vip") &&
          identical(action$arguments$action, "invite_segment"),
        reason = "only a vip invite_segment draft is allowed"
      ))
    }
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_marketing <- function(dataset_name = "fixture", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$reads <- 0L
  state$drafts <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(dataset_name),
      "Segment the fixed customer fixture and draft a review-only campaign.",
      tools = list(
        segment_tool(state, simulate_failure),
        draft_tool(state)
      ),
      allowed_tools = c("segment_customers", "draft_campaign"),
      policy = marketing_policy,
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
  success <- run_marketing()
  stopifnot(
    is.null(success$error),
    identical(success$reads, 1L),
    identical(success$drafts, 1L)
  )
  report <- json_parse(success$output)
  stopifnot(
    as.integer(report$segmentation$customers) == 8L,
    as.integer(report$segmentation$consented) == 6L,
    identical(report$segmentation$top_segment, "vip"),
    length(report$segmentation$segments) == 4L,
    identical(report$campaign$status, "draft_only"),
    isTRUE(report$campaign$review_required),
    as.integer(report$campaign$messages_sent) == 0L,
    length(report$mutating_actions) == 0L
  )

  denied <- run_marketing("other")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$reads, 0L),
    identical(denied$drafts, 0L)
  )

  failed <- run_marketing("fixture", TRUE)
  stopifnot(
    !is.null(failed$error),
    identical(failed$reads, 1L),
    identical(failed$drafts, 0L)
  )

  cat("R marketing-segmentation tutorial: all checks passed\n")
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
  outcome <- run_marketing(dataset_name, simulate_failure)
  if (!is.null(outcome$error)) {
    message(sprintf(
      "marketing segmentation failed: reads=%d drafts=%d; %s",
      outcome$reads, outcome$drafts, outcome$error$message
    ))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
