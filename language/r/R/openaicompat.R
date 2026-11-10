openai_compatible <- function(base_url, model, api_key = NULL, transport = NULL, timeout = 60) {
  list(
    baseUrl = sub("/+$", "", if (is.null(base_url)) "" else base_url),
    model = if (is.null(model)) "" else model,
    apiKey = api_key,
    transport = transport,
    timeout = timeout
  )
}

openai_compatible_object <- function(value) {
  if (is.null(value)) value <- list()
  if (!is.list(value)) return(list())
  if (is.null(names(value))) {
    names(value) <- if (length(value) == 0L) character(0) else as.character(seq_along(value))
  }
  value
}

openai_compatible_content <- function(value) {
  content <- value$content
  if ((is.null(content) || !nzchar(content)) && length(value$contentBlocks) > 0L) {
    parts <- vapply(value$contentBlocks, function(block) {
      kind <- block$type %||% block$kind
      if (identical(kind, "text") && !is.null(block$text)) block$text else ""
    }, character(1))
    content <- paste0(parts, collapse = "")
  }
  if (is.null(content)) "" else content
}

openai_compatible_message <- function(value) {
  out <- list(role = value$role, content = openai_compatible_content(value))
  if (identical(value$role, roles$assistant) && length(value$toolCalls) > 0L) {
    out$tool_calls <- lapply(value$toolCalls, function(call) {
      list(
        id = call$id %||% "",
        type = "function",
        "function" = list(
          name = call$name %||% "",
          arguments = json_encode(openai_compatible_object(call$arguments))
        )
      )
    })
  }
  if (identical(value$role, roles$tool) && !is.null(value$toolId) && nzchar(value$toolId)) {
    out$tool_call_id <- value$toolId
  }
  out
}

openai_compatible_payload <- function(adapter, request) {
  messages <- lapply(request$messages %||% list(), openai_compatible_message)
  payload <- list(model = adapter$model, messages = messages)
  tools <- lapply(request$tools %||% list(), function(tool) {
    list(
      type = "function",
      "function" = list(
        name = tool$name,
        description = tool$description %||% "",
        parameters = openai_compatible_object(tool$parameters %||% list(type = "object"))
      )
    )
  })
  if (length(tools) > 0L) payload$tools <- tools
  if (!is.null(request$toolChoice) && nzchar(request$toolChoice)) {
    payload$tool_choice <- request$toolChoice
  }
  if (!is.null(request$responseFormat)) payload$response_format <- request$responseFormat
  if (!is.null(request$temperature) && request$temperature != 0) {
    payload$temperature <- request$temperature
  }
  payload
}

openai_compatible_parse_response <- function(data) {
  choices <- json_array(data, "choices")
  choice <- if (length(choices) > 0L) choices[[1L]] else list()
  wire <- json_get(choice, "message", list())
  tool_calls <- list()
  for (item in json_array(wire, "tool_calls")) {
    function_value <- json_get(item, "function", list())
    raw <- json_get(function_value, "arguments", NULL)
    arguments <- list()
    if (is.character(raw) && nzchar(raw)) {
      parsed <- tryCatch(json_parse(raw), error = function(error) NULL)
      if (is.null(parsed) || !is.list(parsed) || is.null(names(parsed))) {
        praxo_error("PROVIDER_JSON", "provider returned invalid tool arguments")
      }
      arguments <- parsed
    } else if (is.list(raw) && !is.null(names(raw))) {
      arguments <- raw
    }
    tool_calls[[length(tool_calls) + 1L]] <- tool_call(
      json_string(item, "id", ""),
      json_string(function_value, "name", ""),
      arguments
    )
  }
  usage_value <- json_get(data, "usage", list())
  result <- response(
    message(roles$assistant, json_string(wire, "content", ""), tool_calls = tool_calls),
    usage(json_int(usage_value, "prompt_tokens", 0L),
          json_int(usage_value, "completion_tokens", 0L))
  )
  result$finishReason <- json_string(choice, "finish_reason", NULL)
  result
}

openai_compatible_post <- function(adapter, path, payload) {
  if (!nzchar(adapter$baseUrl)) {
    praxo_error("PROVIDER_HTTP", "provider base URL is required")
  }
  input <- tempfile()
  output <- tempfile()
  on.exit(unlink(c(input, output)), add = TRUE)
  writeLines(json_encode(payload), input, useBytes = TRUE)
  args <- c("-sS", "-X", "POST", "-H", "Content-Type: application/json")
  if (!is.null(adapter$apiKey) && nzchar(adapter$apiKey)) {
    args <- c(args, "-H", paste0("Authorization: Bearer ", adapter$apiKey))
  }
  args <- c(args, "--data-binary", paste0("@", input), "-o", output,
            "-w", "%{http_code}", paste0(adapter$baseUrl, path))
  status_text <- tryCatch(
    suppressWarnings(system2("curl", args, stdout = TRUE, stderr = FALSE)),
    error = function(error) character()
  )
  status <- suppressWarnings(as.integer(tail(status_text, 1L)))
  if (is.na(status)) praxo_error("PROVIDER_HTTP", "provider request failed")
  body <- if (file.exists(output)) paste(readLines(output, warn = FALSE), collapse = "\n") else ""
  if (status < 200L || status >= 300L) {
    praxo_error("PROVIDER_HTTP",
                paste0("provider returned HTTP ", status, ": ", substr(body, 1L, 512L)))
  }
  tryCatch(
    json_parse(body),
    error = function(error) praxo_error("PROVIDER_JSON", "provider returned invalid JSON")
  )
}

openai_compatible_generate <- function(adapter, request) {
  payload <- openai_compatible_payload(adapter, request)
  path <- "/chat/completions"
  data <- if (!is.null(adapter$transport)) {
    adapter$transport(path, payload)
  } else {
    openai_compatible_post(adapter, path, payload)
  }
  openai_compatible_parse_response(data)
}

openai_compatible_model <- function(adapter) {
  function(request) openai_compatible_generate(adapter, request)
}
