fake_mcp_protocol_version <- "2024-11-05"

fake_mcp_generic_tool <- function(name) {
  list(
    name = name,
    description = "generic",
    inputSchema = list(type = "object", properties = list())
  )
}

fake_mcp_list_tools <- function(mode, cursor) {
  if (identical(mode, "repeated-cursor")) {
    label <- if (is.null(cursor)) "loop-start" else "loop-more"
    return(list(
      tools = list(fake_mcp_generic_tool(label)),
      nextCursor = "loop"
    ))
  }
  if (identical(mode, "duplicate-name")) {
    if (is.null(cursor)) {
      return(list(
        tools = list(fake_mcp_generic_tool("dup")),
        nextCursor = "page-2"
      ))
    }
    return(list(tools = list(fake_mcp_generic_tool("dup"))))
  }
  if (is.null(cursor)) {
    return(list(
      tools = list(
        list(
          name = "echo",
          description = "Echo input",
          inputSchema = list(
            type = "object",
            properties = list(text = list(type = "string")),
            required = list("text")
          )
        ),
        fake_mcp_generic_tool("add")
      ),
      nextCursor = "page-2"
    ))
  }
  if (identical(cursor, "page-2")) {
    return(list(tools = list(
      fake_mcp_generic_tool("fail"),
      fake_mcp_generic_tool("multi")
    )))
  }
  list(tools = list())
}

fake_mcp_call_tool <- function(params) {
  name <- json_string(params, "name", "")
  arguments <- json_get(params, "arguments", list())
  if (identical(name, "echo")) {
    return(list(
      content = list(list(
        type = "text",
        text = json_string(arguments, "text", "")
      ))
    ))
  }
  if (identical(name, "add")) {
    left <- json_get(arguments, "a", 0)
    right <- json_get(arguments, "b", 0)
    if (is.null(left)) left <- 0
    if (is.null(right)) right <- 0
    total <- left + right
    return(list(
      content = list(list(type = "text", text = as.character(total))),
      structuredContent = list(sum = total)
    ))
  }
  if (identical(name, "multi")) {
    return(list(content = list(
      list(type = "text", text = "one"),
      list(type = "text", text = "two")
    )))
  }
  if (identical(name, "fail")) {
    return(list(
      isError = TRUE,
      content = list(list(type = "text", text = "boom"))
    ))
  }
  list(
    isError = TRUE,
    content = list(list(type = "text", text = paste0("unknown tool ", name)))
  )
}

fake_mcp_response <- function(message, mode = "default") {
  method <- json_string(message, "method", "")
  id <- json_get(message, "id", NULL)
  params <- json_get(message, "params", list())
  if (identical(method, "initialize")) {
    return(list(
      jsonrpc = "2.0",
      id = id,
      result = list(
        protocolVersion = fake_mcp_protocol_version,
        capabilities = list(tools = list()),
        serverInfo = list(name = "fake-mcp", version = "1.0.0")
      )
    ))
  }
  if (identical(method, "notifications/initialized")) return(NULL)
  if (identical(method, "notifications/cancelled")) return(NULL)
  if (identical(method, "tools/list")) {
    return(list(
      jsonrpc = "2.0",
      id = id,
      result = fake_mcp_list_tools(mode, json_get(params, "cursor", NULL))
    ))
  }
  if (identical(method, "tools/call")) {
    if (identical(mode, "hang")) return(NULL)
    return(list(
      jsonrpc = "2.0",
      id = id,
      result = fake_mcp_call_tool(params)
    ))
  }
  if (is.null(id)) return(NULL)
  list(
    jsonrpc = "2.0",
    id = id,
    error = list(code = -32601, message = "method not found")
  )
}

fake_mcp_mode <- function(args) {
  index <- match("--mode", args)
  if (!is.na(index) && index < length(args)) args[[index + 1L]] else "default"
}

fake_mcp_main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  mode <- fake_mcp_mode(args)
  input <- file("stdin", open = "r")
  on.exit(close(input), add = TRUE)
  repeat {
    line <- readLines(input, n = 1L, warn = FALSE)
    if (length(line) == 0L) break
    if (!nzchar(trimws(line))) next
    message <- tryCatch(json_parse(line), error = function(error) NULL)
    if (is.null(message) || !is.list(message) || is.null(names(message))) next
    response <- fake_mcp_response(message, mode)
    if (is.null(response)) next
    cat(json_encode(response), "\n", sep = "")
    flush(stdout())
  }
  invisible(NULL)
}

fake_script <- sub("^--file=", "",
                   grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1L])
if (!is.na(fake_script) && !exists("json_parse", mode = "function")) {
  fake_root <- normalizePath(file.path(dirname(fake_script), "..", "..", ".."))
  source(file.path(fake_root, "language", "r", "R", "json.R"))
}
if (!is.na(fake_script) && identical(basename(fake_script), "fake_mcp_server.R")) {
  fake_mcp_main()
}
