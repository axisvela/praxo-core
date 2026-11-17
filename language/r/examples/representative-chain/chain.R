source("language/r/R/json.R")
source("language/r/R/core.R")
source("language/r/R/mcp.R")
source("language/r/R/otel.R")
source("language/r/R/harmovela.R")

new_effects <- function() {
  state <- new.env(parent = emptyenv())
  state$counts <- list()
  state
}

bump_effect <- function(effects, target) {
  effects$counts[[target]] <- (effects$counts[[target]] %||% 0L) + 1L
  invisible(NULL)
}

effect_count <- function(effects, target) effects$counts[[target]] %||% 0L

new_counter <- function() {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  state
}

record_transport <- function(effects) {
  transport <- new.env(parent = emptyenv())
  transport$outbox <- list()
  transport$start <- function() invisible(NULL)
  transport$send <- function(message) {
    method <- json_string(message, "method", "")
    id <- json_get(message, "id", NULL)
    if (is.null(id)) return(invisible(NULL))
    params <- json_get(message, "params", list())
    result <- if (identical(method, "initialize")) {
      list(
        protocolVersion = "2024-11-05",
        capabilities = list(tools = list()),
        serverInfo = list(name = "chain-mcp", version = "0.0.1")
      )
    } else if (identical(method, "tools/list")) {
      list(tools = list(list(
        name = "record",
        description = "Record a target",
        inputSchema = list(
          type = "object",
          properties = list(target = list(type = "string")),
          required = list("target")
        )
      )))
    } else if (identical(method, "tools/call")) {
      name <- json_string(params, "name", "")
      arguments <- json_get(params, "arguments", list())
      if (identical(name, "record")) {
        target <- json_string(arguments, "target", "")
        bump_effect(effects, target)
        list(
          content = list(list(type = "text", text = paste0("recorded:", target))),
          isError = FALSE
        )
      } else {
        list(
          isError = TRUE,
          content = list(list(type = "text", text = "unknown tool"))
        )
      }
    } else {
      stop(paste0("unexpected method: ", method))
    }
    transport$outbox[[length(transport$outbox) + 1L]] <- list(
      jsonrpc = "2.0",
      id = id,
      result = result
    )
    invisible(NULL)
  }
  transport$receive <- function(timeout) {
    if (length(transport$outbox) == 0L) return(NULL)
    response <- transport$outbox[[1L]]
    transport$outbox <- transport$outbox[-1L]
    response
  }
  transport$close <- function() invisible(NULL)
  transport
}

build_record <- function(effects) {
  client <- mcp_client(record_transport(effects))
  tools <- mcp_tools(client)
  record <- NULL
  for (tool in tools) if (identical(tool$name, "record")) record <- tool
  if (is.null(record)) praxo_error("CHAIN_TOOL", "missing record tool")
  list(client = client, record = record)
}

scripted_model <- function(steps, final_output, counter) {
  state <- new.env(parent = emptyenv())
  state$index <- 1L
  function(request) {
    counter$calls <- counter$calls + 1L
    if (state$index <= length(steps)) {
      step <- steps[[state$index]]
      state$index <- state$index + 1L
      return(response(message(
        roles$assistant,
        step$content %||% "",
        tool_calls = step$toolCalls %||% list()
      )))
    }
    response(message(roles$assistant, final_output))
  }
}

parent_policy <- function(action) {
  if (identical(action$kind, "model.generate")) return(list(allowed = TRUE))
  if (!identical(action$kind, "tool.invoke")) {
    return(list(allowed = FALSE, reason = "unsupported action"))
  }
  if (identical(action$toolName, "record")) {
    if (identical(action$arguments$target %||% "", "blocked")) {
      return(list(allowed = FALSE, reason = "blocked target"))
    }
    return(list(allowed = TRUE))
  }
  if (identical(action$toolName, "delegate")) return(list(allowed = TRUE))
  list(allowed = FALSE, reason = "parent tool is not allowed")
}

child_only_policy <- function(action) {
  if (identical(action$kind, "model.generate")) return(list(allowed = TRUE))
  if (identical(action$kind, "tool.invoke") &&
      identical(action$toolName, "record")) {
    return(list(allowed = TRUE))
  }
  list(allowed = FALSE, reason = "child may only record")
}

composed_policy <- function(hooks) {
  function(action) {
    for (hook in hooks) {
      decision <- hook(action)
      if (!isTRUE(decision$allowed)) return(decision)
    }
    list(allowed = TRUE, reason = "delegation policy chain allowed")
  }
}

delegate_tool <- function(record, child_model, effects, events) {
  list(
    name = "delegate",
    description = "Run a governed child agent with the narrowed record scope",
    parameters = list(
      type = "object",
      properties = list(task = list(type = "string")),
      required = list("task")
    ),
    invoke = function(arguments) {
      child <- agent_run(
        model = child_model,
        prompt = "record child",
        tools = list(record),
        events = events,
        max_steps = 3L,
        session_id = "chain-child",
        policy = composed_policy(list(parent_policy, child_only_policy)),
        allowed_tools = "record",
        require_policy = TRUE,
        require_tool_scope = TRUE
      )
      list(output = child$output, effects = effect_count(effects, "child"))
    }
  )
}

run_chain <- function() {
  effects <- new_effects()
  record_state <- build_record(effects)

  otel_events <- character()
  harmovela_events <- character()
  otel_transport <- function(endpoint, body) {
    payload <- json_parse(body)
    for (resource in payload$resourceSpans) {
      for (scope in resource$scopeSpans) {
        for (span in scope$spans) otel_events <<- c(otel_events, span$name)
      }
    }
    list(status = 200L, body = "")
  }
  harmovela_transport <- function(path, envelope) {
    harmovela_events <<- c(harmovela_events, envelope$type)
    list(status = 202L, body = "")
  }
  events <- multi_sink(list(
    otel_sink(transport = otel_transport),
    harmovela_sink(
      base_url = "http://harmovela.local",
      transport = harmovela_transport
    )
  ))

  child_counter <- new_counter()
  child_model <- scripted_model(
    list(list(toolCalls = list(
      tool_call("child-record", "record", list(target = "child"))
    ))),
    "CHILD-DONE",
    child_counter
  )
  parent_model <- scripted_model(
    list(
      list(toolCalls = list(
        tool_call("parent-record", "record", list(target = "parent"))
      )),
      list(toolCalls = list(
        tool_call("parent-delegate", "delegate", list(task = "child"))
      ))
    ),
    "DONE",
    new_counter()
  )

  result <- agent_run(
    model = parent_model,
    prompt = "run the representative chain",
    tools = list(
      record_state$record,
      delegate_tool(record_state$record, child_model, effects, events)
    ),
    events = events,
    max_steps = 6L,
    session_id = "chain-parent",
    policy = parent_policy,
    allowed_tools = c("record", "delegate"),
    require_policy = TRUE,
    require_tool_scope = TRUE
  )
  mcp_close(record_state$client)

  list(
    output = result$output,
    effects = effects$counts,
    child_calls = child_counter$calls,
    otel = otel_events,
    harmovela = harmovela_events
  )
}

run_denial <- function() {
  effects <- new_effects()
  record_state <- build_record(effects)
  model <- scripted_model(
    list(list(toolCalls = list(
      tool_call("denied-record", "record", list(target = "safe"))
    ))),
    "UNEXPECTED",
    new_counter()
  )
  edit <- list(before_tool = function(call) {
    call$arguments$target <- "blocked"
    call
  })
  error <- tryCatch({
    agent_run(
      model = model,
      prompt = "call record",
      tools = list(record_state$record),
      max_steps = 2L,
      session_id = "chain-denial",
      policy = parent_policy,
      middleware = list(edit),
      allowed_tools = "record",
      require_policy = TRUE,
      require_tool_scope = TRUE
    )
    NULL
  }, error = function(caught) caught)
  mcp_close(record_state$client)
  if (is.null(error)) {
    praxo_error("CHAIN_DENIAL", "denial path unexpectedly succeeded")
  }
  list(blocked = effect_count(effects, "blocked"), code = error_code(error))
}

main <- function() {
  result <- run_chain()
  stopifnot(identical(result$output, "DONE"))
  stopifnot(identical(result$effects$parent %||% 0L, 1L))
  stopifnot(identical(result$effects$child %||% 0L, 1L))
  stopifnot(result$child_calls >= 2L)
  for (name in c("praxo.run.started", "praxo.tool.call", "praxo.run.completed")) {
    stopifnot(name %in% result$otel)
  }
  for (kind in c("run.started", "tool.call", "run.completed")) {
    stopifnot(kind %in% result$harmovela)
  }
  denial <- run_denial()
  stopifnot(identical(denial$blocked, 0L))
  stopifnot(identical(denial$code, "AGENT_POLICY_DENIED"))
  cat("output:", result$output, "\n")
  cat(sprintf("effects: parent=%d child=%d\n",
              as.integer(result$effects$parent),
              as.integer(result$effects$child)))
  cat("child calls:", result$child_calls, "\n")
  cat("otel spans:", length(result$otel), "\n")
  cat("harmovela events:", length(result$harmovela), "\n")
  cat("denied effects:", denial$blocked, "\n")
}

main()
