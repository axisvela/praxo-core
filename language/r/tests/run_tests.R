if (requireNamespace("praxocore", quietly = TRUE)) {
  library(praxocore)
} else {
  args <- commandArgs(trailingOnly = FALSE)
  script_arg <- args[grep("^--file=", args)]
  script <- sub("^--file=", "", script_arg[1])
  root <- normalizePath(file.path(dirname(script), "..", "..", ".."))
  source(file.path(root, "language", "r", "R", "json.R"))
  source(file.path(root, "language", "r", "R", "toolcall.R"))
  source(file.path(root, "language", "r", "R", "jsonschema.R"))
  source(file.path(root, "language", "r", "R", "plugin.R"))
  source(file.path(root, "language", "r", "R", "core.R"))
  source(file.path(root, "language", "r", "R", "openaicompat.R"))
  source(file.path(root, "language", "r", "R", "harmovela.R"))
}

expect_code <- function(expr, code) {
  error <- tryCatch({ force(expr); NULL }, error = function(e) e)
  stopifnot(inherits(error, "praxo_error"), identical(error$code, code))
}

call <- toolcall_parse('{"name":"echo","input":{"text":"hi"}}')
stopifnot(!is.null(call), identical(call$name, "echo"), identical(call$input$text, "hi"))
stopifnot(identical(
  toolcall_strip('hello<tool_call name="echo">{"text":"hi"}</tool_call>world'),
  "helloworld"
))
schema <- json_parse('{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}')
errors <- schema_validate(schema, json_parse("{}"))
stopifnot(length(errors) == 1L, identical(errors[[1]]$path, "$.name"))
manifest <- plugin_parse_manifest('{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},"health":{},"isolation":"process"}')
stopifnot(identical(manifest$id, "com.example.echo"))

integer_schema <- json_parse('{"type":"integer"}')
stopifnot(length(schema_validate(integer_schema, 2.5)) == 1L)
unicode_schema <- json_parse('{"type":"string","minLength":2,"maxLength":2}')
stopifnot(length(schema_validate(unicode_schema, "你好")) == 0L)
stopifnot(length(schema_validate(unicode_schema, "你")) == 1L)

limit <- call_limit(1L, 1L)
stopifnot(is.null(call_limit_model(limit)))
expect_code(call_limit_model(limit), "AGENT_MODEL_CALL_LIMIT")
stopifnot(is.null(call_limit_tool(limit)))
expect_code(call_limit_tool(limit), "AGENT_TOOL_CALL_LIMIT")

first_run <- call_limit(1L, 0L)
second_run <- call_limit(1L, 0L)
stopifnot(is.null(call_limit_model(first_run)))
stopifnot(is.null(call_limit_model(second_run)))
expect_code(call_limit_model(first_run), "AGENT_MODEL_CALL_LIMIT")

history <- list(messages = list(list(
  content = "email a@b.com",
  toolCalls = list(list(arguments = list(
    email = "a@b.com",
    nested = list(ssn = "123-45-6789")
  )))
)))
redacted <- redact_value(history)
stopifnot(identical(
  redacted$messages[[1L]]$toolCalls[[1L]]$arguments$email,
  "[REDACTED:email]"
))
stopifnot(identical(
  redacted$messages[[1L]]$toolCalls[[1L]]$arguments$nested$ssn,
  "[REDACTED:ssn]"
))
stopifnot(identical(
  history$messages[[1L]]$toolCalls[[1L]]$arguments$email,
  "a@b.com"
))

allow <- checkpoint_allowlist()
checkpoint_register(allow, "spec.payload")
encoded <- checkpoint_marshal(allow, "spec.payload", list(value = "x"))
decoded <- checkpoint_unmarshal(allow, encoded)
stopifnot(identical(decoded$value, "x"))

capacity <- context_budget(2L, 0L)
compacted <- compact_context(capacity, list(message(roles$system, strrep("x", 1000L))))
stopifnot(identical(compacted[[2L]], FALSE))


tool_response <- function(name, arguments) {
  response(message(roles$assistant, "", tool_calls = list(tool_call("c1", name, arguments))))
}

done_response <- response(message(roles$assistant, "done"))

record_policy <- function(deny_tool = FALSE) {
  actions <- list()
  list(
    actions = function() actions,
    hook = function(action) {
      actions[[length(actions) + 1L]] <<- action
      if (deny_tool && identical(action$kind, "tool.invoke")) {
        return(list(allowed = FALSE, reason = "blocked"))
      }
      list(allowed = TRUE, reason = "ok")
    }
  )
}

make_echo_tools <- function(invoked) {
  list(list(
    name = "echo",
    description = "Echo",
    invoke = function(arguments) {
      invoked$items <- c(invoked$items, list(arguments))
      arguments
    }
  ))
}

arguments_test <- function() {
  invoked <- new.env(parent = emptyenv())
  invoked$items <- list()
  step <- 0L
  model <- function(request) {
    step <<- step + 1L
    if (step == 1L) tool_response("echo", list(text = "hi")) else done_response
  }
  policy <- record_policy()
  middleware <- list(list(before_tool = function(call) {
    call$arguments <- list(text = "mutated")
    call
  }))
  result <- agent_run(model, "go", tools = make_echo_tools(invoked),
                      policy = policy$hook, middleware = middleware)
  stopifnot(identical(result$output, "done"))
  stopifnot(identical(invoked$items[[1L]]$text, "mutated"))
  actions <- Filter(function(action) identical(action$kind, "tool.invoke"), policy$actions())
  stopifnot(length(actions) == 2L)
  stopifnot(identical(actions[[1L]]$arguments$text, "hi"))
  stopifnot(identical(actions[[2L]]$arguments$text, "mutated"))
}

final_name_test <- function() {
  echo_invoked <- new.env(parent = emptyenv())
  echo_invoked$items <- list()
  other_invoked <- new.env(parent = emptyenv())
  other_invoked$items <- list()
  step <- 0L
  model <- function(request) {
    step <<- step + 1L
    if (step == 1L) tool_response("echo", list(text = "hi")) else done_response
  }
  tools <- c(
    make_echo_tools(echo_invoked),
    list(list(name = "other", description = "Other", invoke = function(arguments) {
      other_invoked$items <- c(other_invoked$items, list(arguments))
      arguments
    }))
  )
  policy <- record_policy()
  middleware <- list(list(before_tool = function(call) {
    call$name <- "other"
    call
  }))
  agent_run(model, "go", tools = tools, policy = policy$hook, middleware = middleware)
  stopifnot(length(echo_invoked$items) == 0L)
  stopifnot(length(other_invoked$items) == 1L)
  names <- vapply(
    Filter(function(action) identical(action$kind, "tool.invoke"), policy$actions()),
    function(action) action$toolName,
    character(1)
  )
  stopifnot(identical(names, c("echo", "other")))

  denied_invoked <- new.env(parent = emptyenv())
  denied_invoked$items <- list()
  step <- 0L
  denied_model <- function(request) {
    step <<- step + 1L
    if (step == 1L) tool_response("echo", list()) else done_response
  }
  denied <- tryCatch({
    agent_run(denied_model, "go", tools = make_echo_tools(denied_invoked),
              allowed_tools = "echo",
              middleware = list(list(before_tool = function(call) {
                call$name <- "other"
                call
              })))
    NULL
  }, error = function(error) error)
  stopifnot(identical(denied$code, "AGENT_TOOL_NOT_ALLOWED"))
  stopifnot(length(denied_invoked$items) == 0L)
}

unchanged_test <- function() {
  invoked <- new.env(parent = emptyenv())
  invoked$items <- list()
  step <- 0L
  model <- function(request) {
    step <<- step + 1L
    if (step == 1L) tool_response("echo", list(text = "hi")) else done_response
  }
  policy <- record_policy()
  agent_run(model, "go", tools = make_echo_tools(invoked), policy = policy$hook,
            middleware = list(list(before_tool = function(call) call)))
  actions <- Filter(function(action) identical(action$kind, "tool.invoke"), policy$actions())
  stopifnot(length(actions) == 1L)
}

initial_denial_test <- function() {
  invoked <- new.env(parent = emptyenv())
  invoked$items <- list()
  before_tool_calls <- 0L
  step <- 0L
  model <- function(request) {
    step <<- step + 1L
    if (step == 1L) tool_response("echo", list()) else done_response
  }
  policy <- record_policy(deny_tool = TRUE)
  error <- tryCatch({
    agent_run(model, "go", tools = make_echo_tools(invoked), policy = policy$hook,
              middleware = list(list(before_tool = function(call) {
                before_tool_calls <<- before_tool_calls + 1L
                call
              })))
    NULL
  }, error = function(error) error)
  stopifnot(identical(error$code, "AGENT_POLICY_DENIED"))
  stopifnot(before_tool_calls == 0L, length(invoked$items) == 0L)
}

lifecycle_startup_test <- function() {
  calls <- character()
  events <- character()
  sink <- list(emit = function(event) events <<- c(events, event$type))
  middleware <- list(
    list(
      before_run = function(state) calls <<- c(calls, "first.before"),
      after_run = function(result, error) calls <<- c(calls, "first.after")
    ),
    list(
      before_run = function(state) {
        calls <<- c(calls, "second.before")
        stop("startup failed")
      },
      after_run = function(result, error) calls <<- c(calls, "second.after")
    ),
    list(
      before_run = function(state) calls <<- c(calls, "third.before"),
      after_run = function(result, error) calls <<- c(calls, "third.after")
    )
  )
  error <- tryCatch({
    agent_run(function(request) done_response, "go", events = sink, middleware = middleware)
    NULL
  }, error = function(error) error)
  stopifnot(grepl("startup failed", conditionMessage(error), fixed = TRUE))
  stopifnot(identical(calls, c("first.before", "second.before", "first.after", "second.after")))
  stopifnot(length(events) == 0L)
}

lifecycle_continue_test <- function() {
  calls <- character()
  middleware <- list(
    list(after_run = function(result, error) {
      calls <<- c(calls, "first.after")
      stop("cleanup failed")
    }),
    list(after_run = function(result, error) calls <<- c(calls, "second.after"))
  )
  failing_model <- function(request) stop("run failed")
  error <- tryCatch({
    agent_run(failing_model, "go", middleware = middleware)
    NULL
  }, error = function(error) error)
  stopifnot(grepl("run failed", conditionMessage(error), fixed = TRUE))
  stopifnot(identical(calls, c("first.after", "second.after")))
}

lifecycle_failclosed_test <- function() {
  calls <- character()
  events <- character()
  sink <- list(emit = function(event) events <<- c(events, event$type))
  middleware <- list(
    list(after_run = function(result, error) {
      calls <<- c(calls, "first.after")
      stop("cleanup failed")
    }),
    list(after_run = function(result, error) calls <<- c(calls, "second.after"))
  )
  error <- tryCatch({
    agent_run(function(request) done_response, "go", events = sink, middleware = middleware)
    NULL
  }, error = function(error) error)
  stopifnot(grepl("cleanup failed", conditionMessage(error), fixed = TRUE))
  stopifnot(identical(calls, c("first.after", "second.after")))
  stopifnot(identical(events, c("run.started", "run.failed")))
}

arguments_test()
final_name_test()
unchanged_test()
initial_denial_test()
lifecycle_startup_test()
lifecycle_continue_test()
lifecycle_failclosed_test()


model_cancel_test <- function() {
  cancelled <- FALSE
  calls <- character()
  events <- character()
  sink <- list(emit = function(event) events <<- c(events, event$type))
  model <- function(request) {
    cancelled <<- TRUE
    done_response
  }
  error <- tryCatch({
    agent_run(model, "go", events = sink, cancellation = function() cancelled,
              middleware = list(list(after_run = function(result, error) {
                calls <<- c(calls, "after")
              })))
    NULL
  }, error = function(error) error)
  stopifnot(identical(error$code, "AGENT_CANCELLED"))
  stopifnot(identical(calls, "after"))
  stopifnot(identical(events, c("run.started", "run.failed")))
}

tool_cancel_test <- function() {
  cancelled <- FALSE
  effects <- 0L
  calls <- character()
  tools <- list(
    list(name = "cancel", description = "Cancel", invoke = function(arguments) {
      cancelled <<- TRUE
      NULL
    }),
    list(name = "effect", description = "Effect", invoke = function(arguments) {
      effects <<- effects + 1L
      NULL
    })
  )
  step <- 0L
  model <- function(request) {
    step <<- step + 1L
    if (step == 1L) {
      response(message(roles$assistant, "", tool_calls = list(
        tool_call("c1", "cancel", list()),
        tool_call("c2", "effect", list())
      )))
    } else {
      done_response
    }
  }
  error <- tryCatch({
    agent_run(model, "go", tools = tools, cancellation = function() cancelled,
              middleware = list(list(after_run = function(result, error) {
                calls <<- c(calls, "after")
              })))
    NULL
  }, error = function(error) error)
  stopifnot(identical(error$code, "AGENT_CANCELLED"))
  stopifnot(effects == 0L, identical(calls, "after"))
}

stream_callback_test <- function() {
  calls <- character()
  events <- character()
  sink <- list(emit = function(event) events <<- c(events, event$type))
  streaming_model <- function(request, on_delta) {
    on_delta("x")
    done_response
  }
  error <- tryCatch({
    agent_run(function(request) done_response, "go", events = sink,
              streaming_model = streaming_model,
              on_delta = function(delta) stop("callback failed"),
              middleware = list(list(after_run = function(result, error) {
                calls <<- c(calls, "after")
              })))
    NULL
  }, error = function(error) error)
  stopifnot(grepl("callback failed", conditionMessage(error), fixed = TRUE))
  stopifnot(identical(calls, "after"))
  stopifnot(identical(events, c("run.started", "run.failed")))
}

sse_parser_test <- function() {
  truncated <- 'data: {"choices":[{"delta":{"content":"hi"}}]}\n\n'
  error <- tryCatch(parse_sse_stream(truncated), error = function(error) error)
  stopifnot(identical(error$code, "MODEL_STREAM"))
  half <- 'data: {"choices":[{"delta":{"content":"hi"}}]}\n\ndata: {"choices"'
  error <- tryCatch(parse_sse_stream(half), error = function(error) error)
  stopifnot(identical(error$code, "MODEL_STREAM"))
  complete <- 'data: {"choices":[{"delta":{"content":"hi"}}]}\n\ndata: [DONE]\n\n'
  response <- parse_sse_stream(complete)
  stopifnot(identical(response$message$content, "hi"))
}

model_cancel_test()
tool_cancel_test()
stream_callback_test()
sse_parser_test()


parallel_tools_test <- function() {
  step <- 0L
  second_messages <- new.env(parent = emptyenv())
  second_messages$value <- list()
  model <- function(request) {
    if (step == 0L) {
      step <<- 1L
      return(response(message(roles$assistant, "", tool_calls = list(
        tool_call("a1", "a", list()),
        tool_call("b1", "b", list())
      ))))
    }
    second_messages$value <- request$messages
    done_response
  }
  tools <- list(
    list(name = "a", description = "A", invoke = function(arguments) {
      Sys.sleep(0.2)
      list(name = "a")
    }),
    list(name = "b", description = "B", invoke = function(arguments) {
      Sys.sleep(0.2)
      list(name = "b")
    })
  )
  started <- Sys.time()
  result <- agent_run(model, "go", tools = tools, max_parallel_tools = 2L)
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  stopifnot(identical(result$output, "done"))
  if (.Platform$OS.type != "windows") {
    stopifnot(elapsed < 0.35)
  }
  tool_messages <- Filter(function(item) identical(item$role, roles$tool),
                          second_messages$value)
  names <- vapply(tool_messages, function(item) {
    value <- json_parse(item$content)
    value$name
  }, character(1))
  stopifnot(identical(names, c("a", "b")))
}

hitl_approve_test <- function() {
  calls <- 0L
  step <- 0L
  model <- function(request) {
    if (step == 0L) {
      step <<- 1L
      return(response(message(roles$assistant, "", tool_calls = list(
        tool_call("c1", "echo", list(value = "original"))
      ))))
    }
    response(message(roles$assistant, "done"))
  }
  tools <- list(list(name = "echo", description = "Echo", invoke = function(arguments) {
    calls <<- calls + 1L
    arguments
  }))
  result <- agent_run(model, "go", tools = tools, interrupt_on = "echo",
                      on_interrupt_decision = function(interrupt) {
                        interrupt_decision(interrupt_approve)
                      })
  stopifnot(identical(result$output, "done"), calls == 1L)

  step <- 0L
  calls <- 0L
  expect_code(agent_run(model, "go", tools = tools, interrupt_on = "echo",
                        on_interrupt_decision = function(interrupt) {
                          interrupt_decision(interrupt_reject, reason = "no")
                        }), "AGENT_APPROVAL_DENIED")
  stopifnot(calls == 0L)

  step <- 0L
  calls <- 0L
  expect_code(agent_run(model, "go", tools = tools, interrupt_on = "echo"),
              "AGENT_INTERRUPT_UNHANDLED")
  stopifnot(calls == 0L)

  step <- 0L
  calls <- 0L
  actions <- list()
  policy <- function(action) {
    if (identical(action$kind, "tool.invoke")) {
      actions[[length(actions) + 1L]] <<- action
    }
    list(allowed = TRUE, reason = "")
  }
  agent_run(model, "go", tools = tools, policy = policy, interrupt_on = "echo",
            on_interrupt_decision = function(interrupt) {
              interrupt_decision(interrupt_edit, list(value = "edited"))
            })
  stopifnot(calls == 1L, length(actions) == 2L)
  stopifnot(identical(actions[[2L]]$arguments$value, "edited"))

  step <- 0L
  types <- character()
  events <- list(emit = function(event) types <<- c(types, event$type))
  agent_run(model, "go", tools = tools, events = events, interrupt_on = "echo",
            on_interrupt_decision = function(interrupt) {
              interrupt_decision(interrupt_approve)
            })
  stopifnot(sum(types == "tool.interrupt") == 1L)
}

hitl_approve_test()

parallel_tools_test()

openai_compatible_test <- function() {
  captured <- new.env(parent = emptyenv())
  transport <- function(path, payload) {
    captured$path <- path
    captured$payload <- payload
    json_parse(paste0(
      '{"choices":[{"message":{"role":"assistant","content":"hello",',
      '"tool_calls":[{"id":"call-1","type":"function","function":',
      '{"name":"echo","arguments":"{\\"text\\":\\"hi\\"}"}}]},',
      '"finish_reason":"tool_calls"}],',
      '"usage":{"prompt_tokens":7,"completion_tokens":3}}'
    ))
  }
  adapter <- openai_compatible("https://example.test/v1/", "test-model",
                               api_key = "secret", transport = transport)
  request_value <- request(
    messages = list(
      message(roles$system, "sys"),
      message(roles$user, "hi"),
      message(roles$assistant, "",
              tool_calls = list(tool_call("call-1", "echo", list(text = "hi")))),
      message(roles$tool, '{"ok":true}', tool_id = "call-1")
    ),
    tools = list(tool_spec("echo", "Echo")),
    tool_choice = "auto"
  )
  result <- openai_compatible_generate(adapter, request_value)
  stopifnot(identical(captured$path, "/chat/completions"))
  payload <- captured$payload
  stopifnot(identical(payload$model, "test-model"))
  stopifnot(identical(payload$tool_choice, "auto"))
  stopifnot(identical(payload$messages[[3L]]$tool_calls[[1L]][["function"]]$name, "echo"))
  stopifnot(identical(payload$messages[[3L]]$tool_calls[[1L]][["function"]]$arguments,
                      '{"text":"hi"}'))
  stopifnot(identical(payload$messages[[4L]]$tool_call_id, "call-1"))
  stopifnot(identical(payload$tools[[1L]][["function"]]$name, "echo"))
  stopifnot(identical(payload$tools[[1L]][["function"]]$parameters$type, "object"))
  stopifnot(identical(result$message$content, "hello"))
  stopifnot(identical(result$message$toolCalls[[1L]]$id, "call-1"))
  stopifnot(identical(result$message$toolCalls[[1L]]$name, "echo"))
  stopifnot(identical(result$message$toolCalls[[1L]]$arguments$text, "hi"))
  stopifnot(identical(result$usage$inputTokens, 7L))
  stopifnot(identical(result$usage$outputTokens, 3L))
  stopifnot(identical(result$finishReason, "tool_calls"))

  model <- openai_compatible_model(adapter)
  stopifnot(identical(model(request_value)$message$content, "hello"))

  invalid <- function(path, payload) json_parse(paste0(
    '{"choices":[{"message":{"content":"","tool_calls":[{"id":"call-1",',
    '"function":{"name":"echo","arguments":"not json"}}]}}]}'
  ))
  expect_code(
    openai_compatible_generate(
      openai_compatible("https://example.test/v1", "m", transport = invalid),
      request_value
    ),
    "PROVIDER_JSON"
  )
  expect_code(
    openai_compatible_generate(openai_compatible("", "m"), request_value),
    "PROVIDER_HTTP"
  )
}

openai_compatible_test()

harmovela_test <- function() {
  captured <- new.env(parent = emptyenv())
  transport <- function(path, envelope) {
    captured$path <- path
    captured$envelope <- envelope
    list(status = 201L, body = "")
  }
  sink <- harmovela_sink("http://harmovela.test/aep/api/", transport = transport)
  event <- list(
    type = "tool.call",
    sessionId = "s1",
    runId = "run-123",
    data = list(name = "echo")
  )
  sink$emit(event)
  stopifnot(identical(captured$path, "/events"))
  envelope <- captured$envelope
  stopifnot(identical(envelope$spec_version, "0.2"))
  stopifnot(grepl("^run-123-[0-9]+$", envelope$id))
  stopifnot(identical(envelope$type, "tool.call"))
  stopifnot(identical(envelope$source, "praxo-core"))
  stopifnot(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{9}Z$",
                  envelope$created_at))
  stopifnot(identical(envelope$payload$name, "echo"))
  stopifnot(identical(envelope$payload$session_id, "s1"))
  stopifnot(identical(envelope$payload$run_id, "run-123"))

  custom <- harmovela_sink("http://harmovela.test", source = "custom",
                           spec_version = "0.3", transport = transport)
  merged <- list(
    type = "tool.call",
    sessionId = "s1",
    data = list(name = "echo", session_id = "event-side", run_id = "old")
  )
  custom$emit(merged)
  envelope <- captured$envelope
  stopifnot(identical(envelope$source, "custom"))
  stopifnot(identical(envelope$spec_version, "0.3"))
  stopifnot(startsWith(envelope$id, "s1-"))
  stopifnot(identical(envelope$payload$session_id, "s1"))
  stopifnot(identical(envelope$payload$run_id, "old"))

  for (status in c(200L, 201L, 204L, 299L)) {
    accepted <- harmovela_sink("http://harmovela.test",
                               transport = function(path, envelope) {
                                 list(status = status, body = "")
                               })
    accepted$emit(event)
  }

  failing <- harmovela_sink(
    "http://harmovela.test",
    transport = function(path, envelope) {
      list(status = 503L, body = paste(rep("service down ", 100L), collapse = ""))
    }
  )
  error <- tryCatch({ failing$emit(event); NULL }, error = function(error) error)
  stopifnot(inherits(error, "praxo_error"), identical(error$code, "HARMOVELA_HTTP"))
  stopifnot(grepl("503", conditionMessage(error), fixed = TRUE))
  stopifnot(grepl("service down", conditionMessage(error), fixed = TRUE))
  stopifnot(nchar(conditionMessage(error)) <= 600L)
}

harmovela_test()

cat("R core tests passed\n")
