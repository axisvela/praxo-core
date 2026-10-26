recording_sink <- function() {
  state <- new.env(parent = emptyenv())
  state$types <- character()
  state$emit <- function(event) state$types <- c(state$types, event$type)
  state
}

run_memory <- function(input, expect) {
  store <- memory_store()
  for (put in json_array(input, "puts")) {
    record <- json_get(put, "record", list())
    memory_put(store, json_string(put, "session", ""), memory_record(
      id = json_string(record, "id", ""),
      frame = json_string(record, "frame", ""),
      content = json_string(record, "content", ""),
      created_at = json_string(record, "createdAt", NULL)
    ))
  }
  records <- memory_search(store, json_string(input, "session", ""),
                           json_string(input, "query", ""), json_int(input, "limit", 0L))
  ids <- vapply(records, function(record) record$id, character(1))
  contents <- vapply(records, function(record) record$content, character(1))
  check(json_equals(if (length(ids) == 0L) NULL else as.list(ids), json_get(expect, "ids", NULL)), "ids mismatch")
  check(json_equals(if (length(contents) == 0L) NULL else as.list(contents), json_get(expect, "contents", NULL)), "contents mismatch")
}

run_event <- function(input, expect) {
  events <- lapply(json_array(input, "events"), function(type) event(type, "s1"))
  if (identical(json_string(input, "sink", ""), "multi")) {
    count <- max(1L, json_int(input, "sinkCount", 1L))
    sinks <- lapply(seq_len(count), function(index) recording_sink())
    multi <- multi_sink(sinks)
    for (item in events) sink_emit(multi, item)
    per_sink <- lapply(sinks, function(sink) as.list(sink$types))
    check(json_equals(per_sink, json_get(expect, "perSink", NULL)), "perSink mismatch")
    return(invisible(NULL))
  }
  predicate <- json_get(input, "predicateTypes", NULL)
  sink <- recording_sink()
  filter <- filter_sink(sink, function(item) is.null(predicate) || item$type %in% predicate)
  for (item in events) sink_emit(filter, item)
  check(json_equals(if (length(sink$types) == 0L) NULL else as.list(sink$types),
                    json_get(expect, "delivered", NULL)), "delivered mismatch")
}

run_stream <- function(expect) {
  check(json_equals(as.list(stream_kinds), json_get(expect, "kinds", NULL)), "kinds mismatch")
}

run_checkpoint <- function(input, expect) {
  allow <- checkpoint_allowlist()
  for (type in json_array(input, "registered")) checkpoint_register(allow, type)
  operation <- json_string(input, "operation", "roundtrip")
  type <- json_string(input, "type", "")
  value <- json_get(input, "value", NULL)
  if (operation == "roundtrip") {
    data <- checkpoint_marshal(allow, type, value)
    check(json_equals(checkpoint_unmarshal(allow, data), json_get(expect, "value", NULL)), "value mismatch")
    return(invisible(NULL))
  }
  code <- ""
  tryCatch({
    if (operation == "marshal") checkpoint_marshal(allow, type, value)
    else if (operation == "unmarshal") checkpoint_unmarshal(allow, json_encode(list(type = type, data = value)))
    else stop("unknown checkpoint operation")
  }, error = function(error) code <<- error_code(error))
  check(identical(code, json_string(expect, "errorCode", "")), paste0("errorCode: got ", code))
}

run_policy <- function(input, expect) {
  root <- tempfile("praxo-policy-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  for (dir in json_array(input, "makeDirs")) dir.create(file.path(root, dir), recursive = TRUE, showWarnings = FALSE)
  grants <- lapply(json_array(input, "grants"), function(item) {
    grant_root <- file.path(root, json_string(item, "root", ""))
    dir.create(grant_root, recursive = TRUE, showWarnings = FALSE)
    list(root = grant_root, access = json_string(item, "access", "read"))
  })
  checker <- path_checker(grants)
  target <- file.path(root, json_string(input, "target", ""))
  need <- json_string(input, "need", "read")
  if (isTRUE(json_bool(expect, "error", FALSE))) {
    caught <- FALSE
    tryCatch(path_check(checker, target, need), error = function(e) caught <<- TRUE)
    check(caught, "expected a policy error")
    return(invisible(NULL))
  }
  result <- path_check(checker, target, need)$allowed
  check(identical(result, isTRUE(json_bool(expect, "allowed", FALSE))), "allowed mismatch")
}

run_context <- function(input, expect) {
  messages <- lapply(json_array(input, "messages"), function(item)
    message(json_string(item, "role", ""), json_string(item, "content", NULL)))
  if (identical(json_string(input, "operation", ""), "estimate")) {
    tokens <- estimate_tokens(messages)
    check(tokens == json_int(expect, "tokens", 0L), paste0("tokens: got ", tokens))
    return(invisible(NULL))
  }
  budget <- context_budget(json_int(json_get(input, "budget", list()), "maxTokens", 0L),
                           json_int(json_get(input, "budget", list()), "keepRecent", 0L))
  result <- compact_context(budget, messages)
  check(identical(result[[2L]], isTRUE(json_bool(expect, "ok", FALSE))), "ok mismatch")
  if (!result[[2L]]) return(invisible(NULL))
  tokens <- estimate_tokens(result[[1L]])
  check(tokens == json_int(expect, "tokens", 0L), paste0("tokens: got ", tokens))
  check(json_equals(lapply(result[[1L]], message_wire), json_get(expect, "messages", NULL)), "messages mismatch")
}

run_middleware <- function(input, expect) {
  operation <- json_string(input, "operation", "")
  if (operation == "pii") {
    got <- pii_redact(json_string(input, "text", ""))
    check(identical(got, json_string(expect, "text", "")), paste0("text: got ", got))
  } else if (operation == "pii-value") {
    check(json_equals(redact_value(json_get(input, "value", NULL)), json_get(expect, "value", NULL)), "value mismatch")
  } else if (operation == "structured") {
    output <- structured_output(json_get(input, "schema", list()), json_int(input, "maxRepairs", 0L))
    repair <- json_string(input, "repairOutput", NULL)
    if (!is.null(repair)) output$repairer <- function(text, error) repair
    result <- structured_apply(output, json_string(input, "output", ""))
    if (isTRUE(json_bool(expect, "ok", FALSE))) {
      check(isTRUE(result$ok), "expected success")
      check(identical(result$output, json_string(expect, "output", "")), "output mismatch")
    } else {
      check(!isTRUE(result$ok), "expected error")
      check(identical(result$code, json_string(expect, "errorCode", "")), "errorCode mismatch")
    }
  } else if (operation == "call-limit") {
    state <- call_limit(json_int(input, "modelLimit", 0L), json_int(input, "toolLimit", 0L))
    outcomes <- character()
    for (kind in json_array(input, "calls")) {
      code <- ""
      tryCatch({
        if (kind == "model") call_limit_model(state) else call_limit_tool(state)
        code <- "ok"
      }, error = function(error) code <<- error_code(error))
      outcomes <- c(outcomes, code)
    }
    check(json_equals(as.list(outcomes), json_get(expect, "outcomes", NULL)), "outcomes mismatch")
  } else if (operation == "tool-selection") {
    state <- tool_selection(unlist(json_array(input, "selected"), use.names = FALSE))
    tools <- lapply(json_array(input, "tools"), function(name) tool_spec(name))
    advertised <- vapply(select_tools(state, tools), function(tool) tool$name, character(1))
    check(json_equals(as.list(advertised), json_get(expect, "advertised", NULL)), "advertised mismatch")
    code <- "ok"
    tryCatch(check_tool_selected(state, json_string(input, "requested", "")),
             error = function(error) code <<- error_code(error))
    check(identical(code, json_string(expect, "reject", "")), "reject mismatch")
  } else if (operation == "fallback") {
    content <- json_string(input, "fallbackContent", "")
    handler <- fallback_model(function(request) response(message(roles$assistant, content)))(
      function(request) stop("primary failed"))
    check(identical(handler(request())$message$content, content), "output mismatch")
  }
}

run_agent_loop <- function(input, expect) {
  invocations <- 0L
  tools <- lapply(json_array(input, "tools"), function(tool) list(
    name = json_string(tool, "name", ""),
    description = json_string(tool, "description", ""),
    invoke = function(arguments) { invocations <<- invocations + 1L; arguments }
  ))
  sink <- recording_sink()
  result <- NULL
  failure <- NULL
  tryCatch({
    result <- agent_run(scripted_model(json_array(input, "script")),
                        json_string(input, "prompt", ""), tools, sink,
                        json_int(input, "maxSteps", 0L), json_int(input, "maxTokens", 0L))
  }, error = function(error) failure <<- error)
  if (isTRUE(json_bool(expect, "error", FALSE))) {
    check(!is.null(failure), "unexpected success")
    code <- json_string(expect, "errorCode", NULL)
    if (!is.null(code)) check(identical(error_code(failure), code), paste0("errorCode: got ", error_code(failure)))
  } else {
    check(is.null(failure), conditionMessage(failure))
    check(identical(result$output, json_string(expect, "output", "")), "output mismatch")
    check(result$steps == json_int(expect, "steps", 0L), "steps mismatch")
  }
  check(invocations == json_int(expect, "toolInvocations", 0L), "tool invocations mismatch")
  check(json_equals(if (length(sink$types) == 0L) NULL else as.list(sink$types),
                    json_get(expect, "events", NULL)), "events mismatch")
}
