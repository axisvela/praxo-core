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

tool_spec <- function(name, description = "") list(name = name, description = description)

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
                      max_tokens = 0L, session_id = "s1") {
  run_id <- paste0("run-", format(Sys.time(), "%s"))
  if (max_steps <= 0L) max_steps <- 8L
  messages <- list(message(roles$user, prompt))
  total <- usage()
  emit <- function(type, data = NULL) {
    if (!is.null(events)) sink_emit(events, list(type = type, sessionId = session_id, runId = run_id, data = data))
  }
  emit("run.started")
  tryCatch({
    for (step in seq_len(max_steps)) {
      specs <- lapply(tools, function(tool) tool_spec(tool$name, tool$description %||% ""))
      result <- model(request(messages, specs))
      total <- usage_plus(total, result$usage)
      if (max_tokens > 0L && total$inputTokens + total$outputTokens > max_tokens) {
        praxo_error("AGENT_MAX_TOKENS", "token budget exceeded")
      }
      messages[[length(messages) + 1L]] <- result$message
      if (length(result$message$toolCalls) == 0L) {
        emit("run.completed")
        return(run_result(run_id, result$message$content %||% "", step, total))
      }
      for (call in result$message$toolCalls) {
        tool <- NULL
        for (candidate in tools) if (identical(candidate$name, call$name)) tool <- candidate
        if (is.null(tool)) praxo_error("TOOL_NOT_FOUND", "tool not found")
        emit("tool.call", list(name = call$name, arguments = call$arguments))
        value <- tool$invoke(call$arguments)
        messages[[length(messages) + 1L]] <- message(roles$tool, json_encode(value), tool_id = call$id)
      }
    }
    praxo_error("AGENT_MAX_STEPS", "maximum steps exceeded")
  }, error = function(error) {
    emit("run.failed", list(error = conditionMessage(error)))
    stop(error)
  })
}
