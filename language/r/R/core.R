roles <- list(system = "system", user = "user", assistant = "assistant", tool = "tool")
stream_kinds <- c("values", "updates", "messages", "tasks", "debug", "checkpoint")

praxo_error <- function(code, message) {
  stop(structure(class = c("praxo_error", "error", "condition"),
                 list(message = message, code = code)))
}

error_code <- function(error) if (inherits(error, "praxo_error")) error$code else ""

message <- function(role, content = NULL, content_blocks = list(), tool_calls = list(), tool_id = NULL) {
  list(role = role, content = content, contentBlocks = content_blocks,
       toolCalls = tool_calls, toolId = tool_id)
}

message_wire <- function(value) {
  out <- list(role = value$role)
  if (!is.null(value$content)) out$content <- value$content
  if (length(value$contentBlocks) > 0L) out$contentBlocks <- value$contentBlocks
  if (length(value$toolCalls) > 0L) out$toolCalls <- value$toolCalls
  if (!is.null(value$toolId)) out$toolId <- value$toolId
  out
}

tool_call <- function(id = "", name = "", arguments = list()) {
  list(id = id, name = name, arguments = arguments)
}

tool_spec <- function(name, description = "", parameters = NULL) {
  value <- list(name = name, description = description)
  if (!is.null(parameters)) value$parameters <- parameters
  value
}

usage <- function(input = 0L, output = 0L) list(inputTokens = input, outputTokens = output)
usage_plus <- function(left, right) usage(left$inputTokens + right$inputTokens,
                                          left$outputTokens + right$outputTokens)

request <- function(messages = list(), tools = list(), tool_choice = NULL) {
  list(messages = messages, tools = tools, toolChoice = tool_choice)
}

response <- function(message, usage_value = NULL) list(message = message, usage = if (is.null(usage_value)) usage() else usage_value)

session <- function(id, messages = list()) list(id = id, messages = messages)

run_result <- function(run_id, output, steps, usage) {
  list(runId = run_id, output = output, steps = steps, usage = usage)
}

memory_record <- function(id = "", frame = "", content = "", created_at = NULL) {
  list(id = id, frame = frame, content = content, createdAt = created_at)
}

event <- function(type, session_id) list(type = type, sessionId = session_id)

interrupt_approve <- "approve"
interrupt_edit <- "edit"
interrupt_reject <- "reject"
interrupt_respond <- "respond"

interrupt <- function(run_id, session_id, call) {
  list(runId = run_id, sessionId = session_id, call = call)
}

interrupt_decision <- function(action, arguments = NULL, response = "", reason = "") {
  list(action = action, arguments = arguments, response = response, reason = reason)
}

sink_emit <- function(sink, event) sink$emit(event)

multi_sink <- function(sinks) {
  list(emit = function(event) for (sink in sinks) sink_emit(sink, event))
}

filter_sink <- function(sink, predicate) {
  list(emit = function(event) if (predicate(event)) sink_emit(sink, event))
}

memory_store <- function() {
  store <- new.env(parent = emptyenv())
  store$records <- list()
  store$sequence <- 0L
  store
}

memory_put <- function(store, session_id, record) {
  if (!nzchar(record$id)) {
    record$id <- paste0("mem-", format(Sys.time(), "%s"), "-", store$sequence)
    store$sequence <- store$sequence + 1L
  }
  if (is.null(record$createdAt)) record$createdAt <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  store$records[[session_id]] <- c(store$records[[session_id]], list(record))
  record
}

memory_search <- function(store, session_id, query, limit) {
  records <- store$records[[session_id]]
  if (is.null(records)) return(list())
  needle <- tolower(trimws(query))
  matches <- Filter(function(record) !nzchar(needle) || grepl(needle, tolower(record$content), fixed = TRUE), records)
  if (length(matches) > 1L) {
    order_index <- order(vapply(matches, function(record) record$createdAt %||% "", character(1)), decreasing = TRUE)
    matches <- matches[order_index]
  }
  if (limit > 0L) matches <- head(matches, limit)
  matches
}

`%||%` <- function(left, right) if (is.null(left)) right else left

checkpoint_allowlist <- function() {
  allow <- new.env(parent = emptyenv())
  allow$registered <- character()
  allow
}

checkpoint_register <- function(allow, type) {
  if (!nzchar(type)) stop("checkpoint: type is required")
  allow$registered <- unique(c(allow$registered, type))
  invisible(NULL)
}

checkpoint_marshal <- function(allow, type, value) {
  if (!(type %in% allow$registered)) praxo_error("CHECKPOINT_TYPE_NOT_ALLOWED", "checkpoint: payload type not allowed")
  json_encode(list(type = type, data = value))
}

checkpoint_unmarshal <- function(allow, data) {
  envelope <- json_parse(data)
  if (!is.list(envelope) || is.null(names(envelope))) praxo_error("CHECKPOINT_ERROR", "checkpoint: envelope must be an object")
  type <- json_string(envelope, "type", "")
  if (!(type %in% allow$registered)) praxo_error("CHECKPOINT_TYPE_NOT_ALLOWED", "checkpoint: payload type not allowed")
  json_get(envelope, "data", NULL)
}

resolve_path <- function(value) {
  real <- tryCatch(normalizePath(value, mustWork = TRUE), error = function(e) NULL)
  if (!is.null(real)) return(real)
  parent <- dirname(value)
  if (parent == value) return(value)
  file.path(resolve_path(parent), basename(value))
}

path_checker <- function(grants) {
  lapply(grants, function(grant) {
    if (!nzchar(grant$root)) stop("policy: path grant root is required")
    if (!(grant$access %in% c("read", "write", "readwrite"))) stop("policy: invalid grant access")
    list(root = resolve_path(grant$root), access = grant$access)
  })
}

path_within <- function(root, target) {
  root <- sub("[/\\\\]+$", "", root)
  target <- sub("[/\\\\]+$", "", target)
  if (identical(tolower(root), tolower(target))) return(TRUE)
  startsWith(tolower(target), paste0(tolower(root), .Platform$file.sep))
}

path_check <- function(checker, target, need) {
  if (!(need %in% c("read", "write", "readwrite"))) stop("policy: invalid requested access")
  if (length(checker) == 0L) return(list(allowed = FALSE, reason = "no allowed roots"))
  resolved <- resolve_path(target)
  matched <- NULL
  for (grant in checker) {
    if (!path_within(grant$root, resolved)) next
    matched <- grant$root
    allowed <- switch(need,
      read = grant$access %in% c("read", "readwrite"),
      write = grant$access %in% c("write", "readwrite"),
      readwrite = grant$access == "readwrite"
    )
    if (allowed) return(list(allowed = TRUE, reason = "allowed"))
  }
  list(allowed = FALSE, reason = if (is.null(matched)) "outside roots" else "insufficient grant")
}

estimate_tokens <- function(messages) {
  total <- 0L
  for (message in messages) {
    total <- total + 4L + nchar(message$content %||% "", type = "bytes") %/% 4L +
      nchar(message$toolId %||% "", type = "bytes") %/% 4L
    for (block in message$contentBlocks) total <- total + 4L + nchar(block$text %||% "", type = "bytes") %/% 4L
    for (call in message$toolCalls) total <- total + 4L + nchar(call$name, type = "bytes") %/% 4L +
      nchar(json_encode(call$arguments), type = "bytes") %/% 4L
  }
  total
}

truncate_tokens <- function(value, tokens) {
  if (tokens <= 0L) return("")
  limit <- tokens * 4L
  if (nchar(value, type = "bytes") <= limit) return(value)
  if (limit <= 16L) return(substr(value, 1L, limit))
  paste0(substr(value, 1L, limit - 16L), "\n[truncated]")
}

context_budget <- function(max_tokens, keep_recent) list(maxTokens = max_tokens, keepRecent = keep_recent)

compact_context <- function(budget, messages) {
  if (budget$maxTokens == 0L || estimate_tokens(messages) <= budget$maxTokens) return(list(messages, TRUE))
  system <- list()
  rest <- list()
  for (message in messages) {
    if (message$role == roles$system) {
      if (startsWith(message$content %||% "", "[context compacted:")) next
      system[[length(system) + 1L]] <- message
    } else {
      rest[[length(rest) + 1L]] <- message
    }
  }
  if (estimate_tokens(system) > budget$maxTokens) {
    if (length(system) == 0L) return(list(list(), FALSE))
    first <- system[[1L]]
    first$content <- truncate_tokens(first$content %||% "", max(0L, budget$maxTokens - 4L))
    system <- list(first)
    if (estimate_tokens(system) > budget$maxTokens) return(list(list(), FALSE))
  }
  keep <- if (budget$keepRecent > 0L) budget$keepRecent else 4L
  start <- max(0L, length(rest) - keep)
  while (start > 0L && rest[[start + 1L]]$role == roles$tool) start <- start - 1L
  marker <- message(roles$system, paste0("[context compacted: ", start, " older messages omitted]"))
  kept <- if (start >= length(rest)) list() else rest[(start + 1L):length(rest)]
  output <- c(system, if (start > 0L) list(marker) else list(), kept)
  while (estimate_tokens(output) > budget$maxTokens && length(kept) > 1L) {
    if (kept[[2L]]$role == roles$tool) break
    kept <- kept[-1L]
    output <- c(system, if (start > 0L) list(marker) else list(), kept)
  }
  list(output, estimate_tokens(output) <= budget$maxTokens)
}

pii_redact <- function(text) {
  text <- gsub("[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}", "[REDACTED:email]", text, perl = TRUE)
  text <- gsub("\\b\\d{3}-\\d{2}-\\d{4}\\b", "[REDACTED:ssn]", text, perl = TRUE)
  gsub("\\b(?:\\d{4}[ -]?){3}\\d{4}\\b", "[REDACTED:credit_card]", text, perl = TRUE)
}

redact_value <- function(value) {
  if (is.character(value)) return(pii_redact(value))
  if (is.list(value)) {
    out <- lapply(value, redact_value)
    names(out) <- names(value)
    return(out)
  }
  value
}

structured_output <- function(schema, max_repairs = 0L, repairer = NULL) {
  list(schema = schema, maxRepairs = max_repairs, repairer = repairer)
}

structured_apply <- function(output, text) {
  last <- NULL
  for (attempt in 0:output$maxRepairs) {
    data <- tryCatch(extract_json(text), error = function(e) { last <<- e; NULL })
    if (!is.null(data)) {
      errors <- schema_validate(output$schema, data)
      if (length(errors) == 0L) return(list(ok = TRUE, output = text))
      last <- structure(class = c("praxo_error", "error", "condition"),
                        list(message = "schema mismatch", code = "AGENT_STRUCTURED_OUTPUT"))
    }
    if (attempt == output$maxRepairs || is.null(output$repairer)) break
    text <- output$repairer(text, last)
    if (!nzchar(trimws(text))) praxo_error("AGENT_STRUCTURED_OUTPUT", "repair returned empty output")
  }
  list(ok = FALSE, code = "AGENT_STRUCTURED_OUTPUT")
}

extract_json <- function(text) {
  value <- trimws(text)
  if (!nzchar(value)) stop("empty output")
  if (startsWith(value, "```")) {
    value <- sub("^```[^\\n]*\\n", "", value)
    value <- sub("```\\s*$", "", value)
  }
  start <- regexpr("[\\{\\[]", value, perl = TRUE)
  if (start < 0L) stop("output does not contain JSON")
  json_parse(substr(value, start, nchar(value)))
}

call_limit <- function(model_limit, tool_limit) {
  state <- new.env(parent = emptyenv())
  state$model <- 0L
  state$tool <- 0L
  state$modelLimit <- model_limit
  state$toolLimit <- tool_limit
  state
}

call_limit_model <- function(state) {
  state$model <- state$model + 1L
  if (state$modelLimit > 0L && state$model > state$modelLimit) {
    praxo_error("AGENT_MODEL_CALL_LIMIT", "model call limit")
  }
}

call_limit_tool <- function(state) {
  state$tool <- state$tool + 1L
  if (state$toolLimit > 0L && state$tool > state$toolLimit) {
    praxo_error("AGENT_TOOL_CALL_LIMIT", "tool call limit")
  }
}

tool_selection <- function(selected) {
  state <- new.env(parent = emptyenv())
  state$selected <- selected
  state
}

select_tools <- function(state, tools) {
  Filter(function(tool) tool$name %in% state$selected, tools)
}

check_tool_selected <- function(state, name) {
  if (!(name %in% state$selected)) praxo_error("AGENT_TOOL_NOT_SELECTED", "tool not selected")
}

fallback_model <- function(fallback) {
  function(next_model) function(request) {
    tryCatch(next_model(request), error = function(primary) {
      tryCatch(fallback(request), error = function(e) stop(primary))
    })
  }
}

scripted_model <- function(steps) {
  state <- new.env(parent = emptyenv())
  state$index <- 1L
  function(request) {
    if (state$index > length(steps)) stop("script exhausted")
    step <- steps[[state$index]]
    state$index <- state$index + 1L
    calls <- lapply(step$toolCalls %||% list(), function(call) {
      tool_call(call$id %||% "", call$name %||% "", call$arguments %||% list())
    })
    response(message(roles$assistant, step$content %||% "", tool_calls = calls),
             usage(step$inputTokens %||% 0L, step$outputTokens %||% 0L))
  }
}

agent_run <- function(model, prompt, tools = list(), events = NULL, max_steps = 8L,
                      max_tokens = 0L, session_id = "s1", policy = NULL,
                      middleware = list(), allowed_tools = character(),
                      cancellation = NULL, streaming_model = NULL,
                      on_delta = NULL, max_parallel_tools = 0L,
                      interrupt_on = character(), on_interrupt_decision = NULL,
                      on_interrupt = NULL) {
  run_id <- paste0("run-", format(Sys.time(), "%s"))
  if (max_steps <= 0L) max_steps <- 8L
  messages <- list(message(roles$user, prompt))
  total <- usage()
  emit <- function(type, data = NULL) {
    if (!is.null(events)) sink_emit(events, list(type = type, sessionId = session_id, runId = run_id, data = data))
  }
  check_cancel <- function() {
    if (!is.null(cancellation) && isTRUE(cancellation())) {
      praxo_error("AGENT_CANCELLED", "agent: cancelled")
    }
    invisible(NULL)
  }
  authorize <- function(action) {
    if (is.null(policy)) return(invisible(NULL))
    decision <- policy(action)
    if (!isTRUE(decision$allowed)) {
      praxo_error("AGENT_POLICY_DENIED",
                  paste0("agent: ", action$kind, " denied: ", decision$reason %||% ""))
    }
    invisible(NULL)
  }
  tool_allowed <- function(name) {
    length(allowed_tools) == 0L || name %in% allowed_tools
  }
  apply_interrupt <- function(call) {
    if (!(call$name %in% interrupt_on)) {
      return(list(call = call, skip = FALSE))
    }
    if (is.null(on_interrupt_decision) && is.null(on_interrupt)) {
      praxo_error("AGENT_INTERRUPT_UNHANDLED",
                  "agent: approval handler not configured")
    }
    emit("tool.interrupt", list(name = call$name, arguments = call$arguments))
    request <- interrupt(run_id, session_id, call)
    if (!is.null(on_interrupt_decision)) {
      decision <- on_interrupt_decision(request)
      action <- decision$action %||% ""
      if (action == interrupt_approve) {
        return(list(call = call, skip = FALSE))
      }
      if (action == interrupt_edit) {
        if (is.null(decision$arguments)) {
          praxo_error("AGENT_INTERRUPT_DECISION_INVALID",
                      "agent: edit requires arguments")
        }
        call$arguments <- decision$arguments
        return(list(call = call, skip = FALSE))
      }
      if (action == interrupt_reject) {
        praxo_error("AGENT_APPROVAL_DENIED",
                    paste0("agent: tool call denied by approval: ", call$name,
                           ": ", decision$reason %||% ""))
      }
      if (action == interrupt_respond) {
        return(list(call = call, skip = TRUE,
                    value = decision$response %||% ""))
      }
      praxo_error("AGENT_INTERRUPT_DECISION_INVALID",
                  paste0("agent: invalid interrupt decision: ", action))
    }
    if (!isTRUE(on_interrupt(request))) {
      praxo_error("AGENT_APPROVAL_DENIED",
                  paste0("agent: tool call denied by approval: ", call$name))
    }
    list(call = call, skip = FALSE)
  }
  entered <- integer()
  before_run <- function(state) {
    for (index in seq_along(middleware)) {
      entered <<- c(entered, index)
      hook <- middleware[[index]]$before_run
      if (!is.null(hook)) hook(state)
    }
  }
  after_run <- function(result, error) {
    first_error <- NULL
    for (index in entered) {
      hook <- middleware[[index]]$after_run
      if (is.null(hook)) next
      tryCatch(hook(result, error), error = function(caught) {
        if (is.null(first_error)) first_error <<- caught
      })
    }
    first_error
  }
  check_cancel()
  state <- list(runId = run_id, prompt = prompt)
  startup_error <- tryCatch({ before_run(state); NULL }, error = function(error) error)
  if (!is.null(startup_error)) {
    after_run(NULL, startup_error)
    stop(startup_error)
  }
  emit("run.started")
  after_run_invoked <- FALSE
  tryCatch({
    for (step in seq_len(max_steps)) {
      check_cancel()
      specs <- lapply(tools, function(tool) {
        tool_spec(tool$name, tool$description %||% "", tool$parameters %||% NULL)
      })
      request_value <- request(messages, specs)
      result <- if (!is.null(on_delta) && !is.null(streaming_model)) {
        streaming_model(request_value, on_delta)
      } else {
        model(request_value)
      }
      check_cancel()
      total <- usage_plus(total, result$usage)
      if (max_tokens > 0L && total$inputTokens + total$outputTokens > max_tokens) {
        praxo_error("AGENT_MAX_TOKENS", "token budget exceeded")
      }
      messages[[length(messages) + 1L]] <- result$message
      if (length(result$message$toolCalls) == 0L) {
        outcome <- run_result(run_id, result$message$content %||% "", step, total)
        after_run_invoked <- TRUE
        cleanup_error <- after_run(outcome, NULL)
        if (!is.null(cleanup_error)) stop(cleanup_error)
        emit("run.completed")
        return(outcome)
      }
      prepared <- list()
      for (call in result$message$toolCalls) {
        check_cancel()
        original_name <- call$name
        original_arguments <- call$arguments
        if (!tool_allowed(original_name)) {
          praxo_error("AGENT_TOOL_NOT_ALLOWED",
                      paste0("agent: tool ", original_name, " is not allowed"))
        }
        authorize(list(kind = "tool.invoke", sessionId = session_id,
                       toolName = original_name, arguments = original_arguments))
        for (item in middleware) {
          hook <- item$before_tool
          if (!is.null(hook)) call <- hook(call)
        }
        if (!tool_allowed(call$name)) {
          praxo_error("AGENT_TOOL_NOT_ALLOWED",
                      paste0("agent: tool ", call$name, " is not allowed"))
        }
        interrupted <- apply_interrupt(call)
        call <- interrupted$call
        if (isTRUE(interrupted$skip)) {
          prepared[[length(prepared) + 1L]] <- list(call = call, skip = TRUE,
                                                    value = interrupted$value)
          next
        }
        if (!identical(call$name, original_name) ||
            !identical(call$arguments, original_arguments)) {
          authorize(list(kind = "tool.invoke", sessionId = session_id,
                         toolName = call$name, arguments = call$arguments))
        }
        tool <- NULL
        for (candidate in tools) if (identical(candidate$name, call$name)) tool <- candidate
        if (is.null(tool)) praxo_error("TOOL_NOT_FOUND", "tool not found")
        emit("tool.call", list(name = call$name, arguments = call$arguments))
        prepared[[length(prepared) + 1L]] <- list(tool = tool, call = call)
      }
      execute <- function(item) {
        if (isTRUE(item$skip)) {
          return(list(value = item$value))
        }
        if (!is.null(cancellation) && isTRUE(cancellation())) {
          return(list(error = tryCatch(
            praxo_error("AGENT_CANCELLED", "agent: cancelled"),
            error = function(error) error
          )))
        }
        tryCatch(
          list(value = item$tool$invoke(item$call$arguments)),
          error = function(error) list(error = error)
        )
      }
      workers <- min(max_parallel_tools, length(prepared))
      values <- if (workers > 1L) {
        if (.Platform$OS.type == "windows") {
          cluster <- parallel::makeCluster(workers)
          on.exit(parallel::stopCluster(cluster), add = TRUE)
          parallel::parLapply(cluster, prepared, execute)
        } else {
          parallel::mclapply(prepared, execute, mc.cores = workers)
        }
      } else {
        lapply(prepared, execute)
      }
      for (index in seq_along(prepared)) {
        outcome <- values[[index]]
        if (!is.null(outcome$error)) stop(outcome$error)
        messages[[length(messages) + 1L]] <- message(
          roles$tool, json_encode(outcome$value), tool_id = prepared[[index]]$call$id)
      }
    }
    praxo_error("AGENT_MAX_STEPS", "maximum steps exceeded")
  }, error = function(error) {
    if (!after_run_invoked) after_run(NULL, error)
    emit("run.failed", list(error = conditionMessage(error)))
    stop(error)
  })
}

parse_sse_stream <- function(text, on_delta = function(delta) invisible(NULL)) {
  content <- character()
  finish_reason <- NULL
  done <- FALSE
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  for (line in lines) {
    if (!startsWith(line, "data:")) next
    data <- trimws(sub("^data:", "", line))
    if (identical(data, "[DONE]")) {
      done <- TRUE
      break
    }
    chunk <- tryCatch(json_parse(data), error = function(error) NULL)
    if (is.null(chunk)) {
      praxo_error("MODEL_STREAM", "openai-compatible: invalid stream chunk")
    }
    choices <- json_array(chunk, "choices")
    choice <- if (length(choices) > 0L) choices[[1L]] else list()
    reason <- json_string(choice, "finish_reason", NULL)
    if (!is.null(reason)) finish_reason <- reason
    delta <- json_string(json_get(choice, "delta", list()), "content", NULL)
    if (!is.null(delta) && nzchar(delta)) {
      content <- c(content, delta)
      on_delta(delta)
    }
  }
  if (!done && is.null(finish_reason)) {
    praxo_error("MODEL_STREAM", "openai-compatible: stream ended before completion")
  }
  response(message(roles$assistant, paste0(content, collapse = "")))
}
