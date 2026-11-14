source("language/r/R/json.R")
source("language/r/R/core.R")
source("language/r/R/mcp.R")

transport <- new.env(parent = emptyenv())
transport$outbox <- list()
transport$start <- function() invisible(NULL)
transport$send <- function(message) {
  method <- json_get(message, "method", "")
  result <- switch(
    method,
    initialize = list(
      protocolVersion = "2024-11-05",
      capabilities = list(tools = list()),
      serverInfo = list(name = "example-mcp", version = "1.0.0")
    ),
    "tools/list" = list(tools = list(
      list(name = "echo", description = "Echo input", inputSchema = list(type = "object")),
      list(name = "add", description = "Add two integers", inputSchema = list(type = "object"))
    )),
    "tools/call" = list(structuredContent = list(sum = 5L), isError = FALSE),
    stop("unexpected method")
  )
  transport$outbox[[length(transport$outbox) + 1L]] <- list(
    jsonrpc = "2.0",
    id = json_get(message, "id", NULL),
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

client <- mcp_client(transport)
tools <- mcp_list_tools(client)
result <- mcp_call_tool(client, "add", list(a = 2L, b = 3L))
mcp_close(client)

stopifnot(identical(sort(vapply(tools, function(tool) tool$name, "")), c("add", "echo")))
stopifnot(identical(result$sum, 5L))
cat("R MCP example passed\n")
