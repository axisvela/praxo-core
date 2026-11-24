source("language/r/R/json.R")
source("language/r/R/core.R")

fixture_evidence <- function(topic) {
  if (identical(topic, "topic-300")) {
    return(list(citations = list(), available = FALSE))
  }
  list(
    citations = list(
      "guideline-100-section-2",
      "guideline-101-section-5"
    ),
    available = TRUE
  )
}

fixture_model <- function(topic) {
  function(request) {
    tool_messages <- Filter(
      function(item) identical(item$role, roles$tool),
      request$messages
    )
    if (length(tool_messages) > 0L) {
      evidence <- json_parse(tool_messages[[length(tool_messages)]]$content)
      return(response(message(
        roles$assistant,
        json_encode(list(clinical = evidence, diagnoses = list(), treatment_actions = list()))
      )))
    }
    response(message(
      roles$assistant,
      "",
      tool_calls = list(tool_call(
        "evidence-1", "retrieve_guidelines", list(topic = topic)
      ))
    ))
  }
}

retrieve_guidelines_tool <- function(state, simulate_failure) {
  list(
    name = "retrieve_guidelines",
    description = "Retrieve fixed guideline citations; abstain when evidence is missing.",
    parameters = list(
      type = "object",
      required = list("topic"),
      properties = list(topic = list(type = "string"))
    ),
    invoke = function(arguments) {
      state$calls <- state$calls + 1L
      topic <- arguments$topic
      if (!(topic %in% c("topic-100", "topic-300"))) {
        stop("unknown guideline topic")
      }
      if (isTRUE(simulate_failure)) {
        stop("simulated guideline source unavailable")
      }
      evidence <- fixture_evidence(topic)
      list(
        topic = topic,
        citations = evidence$citations,
        citation_count = length(evidence$citations),
        abstained = !evidence$available,
        diagnoses = 0,
        treatment_actions = 0,
        source = "guideline_fixture"
      )
    }
  )
}

guideline_policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    return(list(
      allowed = identical(action$toolName, "retrieve_guidelines") &&
        action$arguments$topic %in% c("topic-100", "topic-300"),
      reason = "only fixed guideline topics are readable"
    ))
  }
  list(allowed = FALSE, reason = "unsupported action")
}

run_case <- function(topic = "topic-100", simulate_failure = FALSE) {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  error <- NULL
  output <- tryCatch({
    result <- agent_run(
      fixture_model(topic),
      "Retrieve fixed citations and abstain when evidence is missing.",
      tools = list(retrieve_guidelines_tool(state, simulate_failure)),
      allowed_tools = "retrieve_guidelines",
      policy = guideline_policy,
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
  success <- run_case("topic-100")
  stopifnot(is.null(success$error), identical(success$calls, 1L))
  report <- json_parse(success$output)
  stopifnot(
    as.integer(report$clinical$citation_count) == 2L,
    identical(report$clinical$citations[[1]], "guideline-100-section-2"),
    identical(report$clinical$abstained, FALSE),
    as.integer(report$clinical$diagnoses) == 0L,
    as.integer(report$clinical$treatment_actions) == 0L,
    length(report$diagnoses) == 0L,
    length(report$treatment_actions) == 0L
  )

  abstain <- run_case("topic-300")
  stopifnot(is.null(abstain$error))
  missing <- json_parse(abstain$output)
  stopifnot(
    identical(missing$clinical$abstained, TRUE),
    as.integer(missing$clinical$citation_count) == 0L,
    length(missing$clinical$citations) == 0L
  )

  denied <- run_case("topic-200")
  stopifnot(
    inherits(denied$error, "praxo_error"),
    identical(denied$error$code, "AGENT_POLICY_DENIED"),
    identical(denied$calls, 0L)
  )

  failed <- run_case("topic-100", TRUE)
  stopifnot(!is.null(failed$error), identical(failed$calls, 1L))

  cat("R clinical-guidelines tutorial: all checks passed\n")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--test" %in% args) {
    run_tests()
    quit(status = 0)
  }
  topic <- "topic-100"
  index <- match("--topic", args)
  if (!is.na(index) && index < length(args)) {
    topic <- args[[index + 1L]]
  }
  outcome <- run_case(topic, "--simulate-failure" %in% args)
  if (!is.null(outcome$error)) {
    message(sprintf("clinical guidelines failed: reads=%d; %s", outcome$calls, outcome$error$message))
    quit(status = 1)
  }
  cat(outcome$output, "\n", sep = "")
}
