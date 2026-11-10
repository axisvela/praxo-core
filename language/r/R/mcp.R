mcp_default_protocol_version <- "2024-11-05"

mcp_stdio_transport <- function(command, args = character(), env = NULL, cwd = NULL) {
  if (is.null(command) || !nzchar(command)) {
    praxo_error("MCP_TRANSPORT", "mcp: command is required")
  }
  praxo_error(
    "MCP_TRANSPORT",
    paste0(
      "mcp: base R cannot open a persistent bidirectional stdio child; ",
      "supply a caller-owned transport (for example one backed by processx)"
    )
  )
}

mcp_notify <- function(client, method, params = NULL) {
  if (isTRUE(client$closed)) return(invisible(NULL))
  message <- list(jsonrpc = "2.0", method = method)
  if (!is.null(params)) message$params <- params
  tryCatch(client$transport$send(message), error = function(error) NULL)
  invisible(NULL)
}

mcp_client <- function(transport, timeout = 30, client_name = "praxo-core",
                       client_version = "0.6.0",
                       protocol_version = mcp_default_protocol_version,
                       cancellation = NULL) {
  if (is.null(transport) || !(is.list(transport) || is.environment(transport))) {
    praxo_error("MCP_TRANSPORT", "mcp: transport is required")
  }
  state <- new.env(parent = emptyenv())
  state$transport <- transport
  state$timeout <- timeout
  state$client_name <- if (nzchar(client_name)) client_name else "praxo-core"
  state$client_version <- client_version
  state$requested_protocol_version <- if (nzchar(protocol_version)) {
    protocol_version
  } else {
    mcp_default_protocol_version
  }
  state$cancellation <- cancellation
  state$protocol_version <- ""
  state$server_info <- list()
  state$server_capabilities <- list()
  state$next_id <- 1L
  state$connected <- FALSE
  state$closed <- FALSE
  tryCatch(transport$start(), error = function(error) {
    praxo_error(
      "MCP_TRANSPORT",
      paste0("mcp: failed to start transport: ", conditionMessage(error))
    )
  })
  result <- tryCatch(
    mcp_request(
      state,
      "initialize",
      list(
        protocolVersion = state$requested_protocol_version,
        capabilities = structure(list(), names = character(0)),
        clientInfo = list(
          name = state$client_name,
          version = state$client_version
        )
      ),
      timeout
    ),
    error = function(error) {
      tryCatch(transport$close(), error = function(close_error) NULL)
      stop(error)
    }
  )
  version <- json_string(result, "protocolVersion", "")
  if (!nzchar(version)) {
    tryCatch(transport$close(), error = function(error) NULL)
    praxo_error("MCP_HANDSHAKE", "mcp: initialize returned no protocol version")
  }
  state$protocol_version <- version
  server_info <- json_get(result, "serverInfo", list())
  state$server_info <- if (is.list(server_info) && !is.null(names(server_info))) {
    server_info
  } else {
    list()
  }
  capabilities <- json_get(result, "capabilities", list())
  state$server_capabilities <- if (is.list(capabilities) && !is.null(names(capabilities))) {
    capabilities
  } else {
    list()
  }
  mcp_notify(state, "notifications/initialized")
  state$connected <- TRUE
  class(state) <- c("praxo_mcp_client", "environment")
  state
}

mcp_close <- function(client) {
  if (isTRUE(client$closed)) return(invisible(NULL))
  client$closed <- TRUE
  client$connected <- FALSE
  tryCatch(client$transport$close(), error = function(error) NULL)
  invisible(NULL)
}

mcp_request <- function(client, method, params = NULL, timeout = NULL) {
  if (isTRUE(client$closed)) {
    praxo_error("MCP_CLOSED", "mcp: client is closed")
  }
  id <- client$next_id
  client$next_id <- id + 1L
  message <- list(jsonrpc = "2.0", id = id, method = method)
  if (!is.null(params)) message$params <- params
  tryCatch(client$transport$send(message), error = function(error) {
    praxo_error(
      "MCP_TRANSPORT",
      paste0("mcp: failed to write to server: ", conditionMessage(error))
    )
  })
  effective <- if (is.null(timeout)) client$timeout else timeout
  deadline <- Sys.time() + effective
  repeat {
    if (!is.null(client$cancellation) && isTRUE(client$cancellation())) {
      mcp_notify(client, "notifications/cancelled",
                 list(requestId = id, reason = "cancelled"))
      praxo_error("MCP_CANCELLED", paste0("mcp: ", method, " cancelled"))
    }
    remaining <- as.numeric(difftime(deadline, Sys.time(), units = "secs"))
    if (remaining <= 0) {
      mcp_notify(client, "notifications/cancelled",
                 list(requestId = id, reason = "timeout"))
      praxo_error(
        "MCP_TIMEOUT",
        paste0("mcp: ", method, " timed out after ", effective, " seconds")
      )
    }
    response <- client$transport$receive(min(remaining, 0.05))
    if (is.null(response)) {
      Sys.sleep(0.005)
      next
    }
    if (!is.list(response) || is.null(names(response))) {
      praxo_error("MCP_PROTOCOL", "mcp: server sent a non-object message")
    }
    if (!identical(json_get(response, "jsonrpc", NULL), "2.0")) {
      praxo_error("MCP_PROTOCOL", "mcp: invalid JSON-RPC version")
    }
    response_id <- json_get(response, "id", NULL)
    if (is.null(response_id)) next
    if (!identical(as.integer(response_id), as.integer(id))) next
    error <- json_get(response, "error", NULL)
    if (!is.null(error) && !is_json_null(error)) {
      if (!is.list(error) || is.null(names(error))) {
        praxo_error("MCP_PROTOCOL", paste0("mcp: ", method, " returned an invalid error"))
      }
      text <- json_string(error, "message", paste0(method, " failed"))
      praxo_error("MCP_RPC", paste0("mcp: ", method, ": ", text))
    }
    result <- json_get(response, "result", NULL)
    if (is.null(result) || !is.list(result) || is.null(names(result))) {
      praxo_error("MCP_PROTOCOL", paste0("mcp: ", method, " result must be an object"))
    }
    return(result)
  }
}

mcp_list_tools <- function(client, timeout = NULL) {
  tools <- list()
  names_seen <- character()
  cursors <- character()
  cursor <- NULL
  repeat {
    params <- if (is.null(cursor)) NULL else list(cursor = cursor)
    result <- mcp_request(client, "tools/list", params, timeout)
    raw <- json_get(result, "tools", list())
    if (!is.list(raw) || !is.null(names(raw))) {
      praxo_error("MCP_PROTOCOL", "mcp: tools/list tools must be a list")
    }
    for (item in raw) {
      if (!is.list(item) || is.null(names(item))) {
        praxo_error("MCP_PROTOCOL", "mcp: tool definition must be an object")
      }
      name <- json_string(item, "name", "")
      if (!nzchar(name)) {
        praxo_error("MCP_PROTOCOL", "mcp: tool name is required")
      }
      if (name %in% names_seen) {
        praxo_error("MCP_DUPLICATE_TOOL", paste0("mcp: duplicate tool ", name))
      }
      schema <- json_get(item, "inputSchema", NULL)
      if (is.null(schema) || !is.list(schema) || is.null(names(schema))) {
        praxo_error("MCP_PROTOCOL", paste0("mcp: missing input schema for ", name))
      }
      names_seen <- c(names_seen, name)
      tools[[length(tools) + 1L]] <- list(
        name = name,
        description = json_string(item, "description", ""),
        title = json_string(item, "title", ""),
        inputSchema = schema,
        annotations = json_get(item, "annotations", list())
      )
    }
    next_cursor <- json_get(result, "nextCursor", NULL)
    if (is.null(next_cursor) || is_json_null(next_cursor)) break
    if (!is.character(next_cursor) || length(next_cursor) != 1L) {
      praxo_error("MCP_PROTOCOL", "mcp: tools/list nextCursor must be a string")
    }
    if (!nzchar(next_cursor)) break
    if (next_cursor %in% cursors) {
      praxo_error("MCP_PAGINATION", "mcp: repeated tool pagination cursor")
    }
    cursors <- c(cursors, next_cursor)
    cursor <- next_cursor
  }
  if (length(tools) > 1L) {
    tools <- tools[order(vapply(tools, function(tool) tool$name, character(1)))]
  }
  tools
}

mcp_text_contents <- function(result) {
  content <- json_get(result, "content", list())
  if (!is.list(content) || !is.null(names(content))) return(character())
  texts <- character()
  for (block in content) {
    if (!is.list(block) || is.null(names(block))) next
    if (!identical(json_string(block, "type", ""), "text")) next
    text <- json_get(block, "text", NULL)
    if (is.character(text) && length(text) == 1L) texts <- c(texts, text)
  }
  texts
}

mcp_call_tool <- function(client, name, arguments = list(), timeout = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("mcp: tool name is required")
  }
  if (!is.list(arguments)) {
    stop("mcp: tool arguments must be an object")
  }
  if (length(arguments) == 0L) {
    names(arguments) <- character(0)
  } else if (is.null(names(arguments))) {
    praxo_error("MCP_PROTOCOL", "mcp: tool arguments must be an object")
  }
  result <- mcp_request(
    client,
    "tools/call",
    list(name = name, arguments = arguments),
    timeout
  )
  if (isTRUE(json_bool(result, "isError", FALSE))) {
    detail <- paste(mcp_text_contents(result), collapse = "\n")
    praxo_error("MCP_TOOL_ERROR", paste0("mcp: tool ", name, " failed: ", detail))
  }
  structured <- json_get(result, "structuredContent", NULL)
  if (!is.null(structured) && !is_json_null(structured)) return(structured)
  texts <- mcp_text_contents(result)
  if (length(texts) == 0L) return(NULL)
  if (length(texts) == 1L) return(texts[[1L]])
  as.list(texts)
}

mcp_tools <- function(client, timeout = NULL) {
  tools <- mcp_list_tools(client, timeout)
  lapply(tools, function(tool) {
    name <- tool$name
    list(
      name = name,
      description = tool$description,
      parameters = tool$inputSchema,
      invoke = function(arguments) mcp_call_tool(client, name, arguments, timeout)
    )
  })
}

mcp_register_tools <- function(client, existing = list(), timeout = NULL) {
  c(existing, mcp_tools(client, timeout))
}
