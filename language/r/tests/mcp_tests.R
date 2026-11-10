fake_mcp_transport <- function(mode = "default") {
  state <- new.env(parent = emptyenv())
  state$mode <- mode
  state$sent <- list()
  state$incoming <- list()
  state$started <- FALSE
  state$closed <- FALSE
  state$start <- function() {
    state$started <- TRUE
    invisible(NULL)
  }
  state$send <- function(message) {
    state$sent[[length(state$sent) + 1L]] <- message
    response <- fake_mcp_response(message, state$mode)
    if (!is.null(response)) {
      state$incoming[[length(state$incoming) + 1L]] <- response
    }
    invisible(NULL)
  }
  state$receive <- function(timeout = NULL) {
    if (length(state$incoming) == 0L) return(NULL)
    response <- state$incoming[[1L]]
    state$incoming <- state$incoming[-1L]
    response
  }
  state$close <- function() {
    state$closed <- TRUE
    invisible(NULL)
  }
  state
}

mcp_handshake_test <- function() {
  transport <- fake_mcp_transport()
  client <- mcp_client(transport, timeout = 5)
  stopifnot(identical(client$protocol_version, "2024-11-05"))
  stopifnot(identical(client$server_info$name, "fake-mcp"))
  tools <- mcp_list_tools(client)
  stopifnot(identical(
    vapply(tools, function(tool) tool$name, character(1)),
    c("add", "echo", "fail", "multi")
  ))
  echo <- Filter(function(tool) identical(tool$name, "echo"), tools)[[1L]]
  stopifnot(identical(echo$inputSchema$type, "object"))
  stopifnot(identical(echo$inputSchema$properties$text$type, "string"))
  stopifnot(identical(echo$inputSchema$required[[1L]], "text"))
  registered <- mcp_register_tools(client)
  registered_echo <- Filter(function(tool) identical(tool$name, "echo"), registered)[[1L]]
  stopifnot(identical(registered_echo$parameters$properties$text$type, "string"))
  mcp_close(client)
  stopifnot(isTRUE(transport$closed))
}

mcp_repeated_cursor_test <- function() {
  client <- mcp_client(fake_mcp_transport("repeated-cursor"), timeout = 5)
  expect_code(mcp_list_tools(client), "MCP_PAGINATION")
  mcp_close(client)
}

mcp_duplicate_name_test <- function() {
  client <- mcp_client(fake_mcp_transport("duplicate-name"), timeout = 5)
  expect_code(mcp_list_tools(client), "MCP_DUPLICATE_TOOL")
  mcp_close(client)
}

mcp_call_test <- function() {
  client <- mcp_client(fake_mcp_transport(), timeout = 5)
  stopifnot(identical(mcp_call_tool(client, "echo", list(text = "hello")), "hello"))
  structured <- mcp_call_tool(client, "add", list(a = 1, b = 2))
  stopifnot(identical(structured$sum, 3))
  multi <- mcp_call_tool(client, "multi")
  stopifnot(identical(multi, list("one", "two")))
  expect_code(mcp_call_tool(client, "fail"), "MCP_TOOL_ERROR")
  expect_code(mcp_request(client, "missing/method"), "MCP_RPC")
  mcp_close(client)
}

mcp_timeout_test <- function() {
  transport <- fake_mcp_transport("hang")
  client <- mcp_client(transport, timeout = 5)
  expect_code(mcp_call_tool(client, "hang", list(), timeout = 0.05), "MCP_TIMEOUT")
  cancelled <- Filter(
    function(item) identical(item$method, "notifications/cancelled"),
    transport$sent
  )
  stopifnot(length(cancelled) == 1L)
  stopifnot(identical(cancelled[[1L]]$params$reason, "timeout"))
  mcp_close(client)
  stopifnot(isTRUE(transport$closed))
}

mcp_cancellation_test <- function() {
  transport <- fake_mcp_transport("hang")
  client <- mcp_client(transport, timeout = 5)
  client$cancellation <- function() TRUE
  expect_code(mcp_call_tool(client, "hang"), "MCP_CANCELLED")
  cancelled <- Filter(
    function(item) identical(item$method, "notifications/cancelled"),
    transport$sent
  )
  stopifnot(length(cancelled) == 1L)
  stopifnot(identical(cancelled[[1L]]$params$reason, "cancelled"))
  mcp_close(client)
}

mcp_policy_test <- function() {
  client <- mcp_client(fake_mcp_transport(), timeout = 5)
  tools <- mcp_register_tools(client)
  step <- 0L
  model <- function(request) {
    step <<- step + 1L
    if (step == 1L) tool_response("echo", list(text = "hi")) else done_response
  }
  expect_code(
    agent_run(
      model,
      "go",
      tools = tools,
      policy = function(action) list(allowed = FALSE, reason = "blocked")
    ),
    "AGENT_POLICY_DENIED"
  )
  mcp_close(client)
}

mcp_stdio_transport_blocked_test <- function() {
  error <- tryCatch(mcp_stdio_transport("missing-server"), error = function(error) error)
  stopifnot(inherits(error, "praxo_error"), identical(error$code, "MCP_TRANSPORT"))
  stopifnot(grepl("persistent bidirectional stdio", conditionMessage(error), fixed = TRUE))
}

mcp_handshake_test()
mcp_repeated_cursor_test()
mcp_duplicate_name_test()
mcp_call_test()
mcp_timeout_test()
mcp_cancellation_test()
mcp_policy_test()
mcp_stdio_transport_blocked_test()

