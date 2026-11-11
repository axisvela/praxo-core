anthropic <- function(base_url = "https://api.anthropic.com",
                      model = "",
                      api_key = NULL,
                      transport = NULL,
                      timeout = 60,
                      version = "2023-06-01",
                      max_tokens = 1024) {
  list(
    baseUrl = sub("/+$", "", if (is.null(base_url)) "" else base_url),
    model = if (is.null(model)) "" else model,
    apiKey = api_key,
    transport = transport,
    timeout = timeout,
    version = version,
    maxTokens = max_tokens
  )
}

anthropic_message <- function(value) {
  content <- list()
  if (!is.null(value$content) && nzchar(value$content)) {
    content[[length(content) + 1L]] <- list(type = "text", text = value$content)
  }
  for (block in value$contentBlocks %||% list()) {
    if (identical(block$type, "text") && !is.null(block$text)) {
      content[[length(content) + 1L]] <- list(type = "text", text = block$text)
    }
  }
  for (call in value$toolCalls %||% list()) {
    content[[length(content) + 1L]] <- list(
      type = "tool_use",
      id = call$id %||% "",
      name = call$name %||% "",
      input = openai_compatible_object(call$arguments)
    )
  }
  content
}

anthropic_payload <- function(adapter, request) {
  system <- character()
  messages <- list()
  tool_results <- list()
  flush <- function() {
    if (length(tool_results) > 0L) {
      messages[[length(messages) + 1L]] <<- list(
        role = "user",
        content = tool_results
      )
      tool_results <<- list()
    }
  }
  for (value in request$messages %||% list()) {
    if (identical(value$role, roles$system)) {
      if (!is.null(value$content) && nzchar(value$content)) {
        system <- c(system, value$content)
      }
      next
    }
    if (identical(value$role, roles$tool)) {
      tool_results[[length(tool_results) + 1L]] <- list(
        type = "tool_result",
        tool_use_id = value$toolId %||% "",
        content = value$content %||% ""
      )
      next
    }
    flush()
    content <- anthropic_message(value)
    if (length(content) > 0L) {
      messages[[length(messages) + 1L]] <- list(
        role = value$role,
        content = content
      )
    }
  }
  flush()
  payload <- list(
    model = adapter$model,
    max_tokens = adapter$maxTokens,
    messages = messages
  )
  if (length(system) > 0L) payload$system <- paste(system, collapse = "\n\n")
  tools <- request$tools %||% list()
  if (length(tools) > 0L) {
    payload$tools <- lapply(tools, function(tool) {
      list(
        name = tool$name,
        description = tool$description %||% "",
        input_schema = openai_compatible_object(
          tool$parameters %||% list(type = "object")
        )
      )
    })
    choice <- anthropic_tool_choice(request$toolChoice)
    if (!is.null(choice)) payload$tool_choice <- choice
  }
  if (!is.null(request$temperature) && request$temperature != 0) {
    payload$temperature <- request$temperature
  }
  payload
}

anthropic_tool_choice <- function(choice) {
  if (is.null(choice) || !nzchar(choice)) return(NULL)
  if (identical(choice, "auto")) return(list(type = "auto"))
  if (identical(choice, "required")) return(list(type = "any"))
  if (identical(choice, "none")) return(list(type = "none"))
  NULL
}

anthropic_parse_response <- function(data) {
  error <- data$error
  if (!is.null(error)) {
    praxo_error("PROVIDER_HTTP", paste0("anthropic: ", error$message %||% "error"))
  }
  text <- character()
  calls <- list()
  for (block in data$content %||% list()) {
    if (identical(block$type, "text")) {
      text <- c(text, block$text %||% "")
    } else if (identical(block$type, "tool_use")) {
      calls[[length(calls) + 1L]] <- tool_call(
        block$id %||% "",
        block$name %||% "",
        openai_compatible_object(block$input)
      )
    }
  }
  usage_value <- data$usage %||% list()
  result <- response(
    message(roles$assistant, paste0(text, collapse = ""), tool_calls = calls),
    usage(
      usage_value$input_tokens %||% 0L,
      usage_value$output_tokens %||% 0L
    )
  )
  result$usage$cachedTokens <- usage_value$cache_read_input_tokens %||% 0L
  result$finishReason <- data$stop_reason
  result
}

anthropic_generate <- function(adapter, request) {
  if (is.null(adapter$apiKey) || !nzchar(adapter$apiKey)) {
    praxo_error("PROVIDER_CONFIG", "anthropic: API key is required")
  }
  if (!nzchar(adapter$model)) {
    praxo_error("PROVIDER_CONFIG", "anthropic: model is required")
  }
  path <- "/v1/messages"
  payload <- anthropic_payload(adapter, request)
  data <- if (!is.null(adapter$transport)) {
    adapter$transport(path, payload)
  } else {
    anthropic_post(adapter, path, payload)
  }
  anthropic_parse_response(data)
}

anthropic_model <- function(adapter) {
  function(request) anthropic_generate(adapter, request)
}

anthropic_post <- function(adapter, path, payload) {
  if (!nzchar(adapter$baseUrl)) {
    praxo_error("PROVIDER_HTTP", "provider base URL is required")
  }
  input <- tempfile()
  output <- tempfile()
  on.exit(unlink(c(input, output)), add = TRUE)
  writeLines(json_encode(payload), input, useBytes = TRUE)
  args <- c(
    "-sS", "-X", "POST",
    "-H", "Content-Type: application/json",
    "-H", paste0("x-api-key: ", adapter$apiKey),
    "-H", paste0("anthropic-version: ", adapter$version),
    "--data-binary", paste0("@", input),
    "-o", output, "-w", "%{http_code}",
    paste0(adapter$baseUrl, path)
  )
  status_text <- tryCatch(
    suppressWarnings(system2("curl", args, stdout = TRUE, stderr = FALSE)),
    error = function(error) character()
  )
  status <- suppressWarnings(as.integer(tail(status_text, 1L)))
  if (is.na(status)) praxo_error("PROVIDER_HTTP", "provider request failed")
  body <- if (file.exists(output)) {
    paste(readLines(output, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  if (status < 200L || status >= 300L) {
    praxo_error(
      "PROVIDER_HTTP",
      paste0("provider returned HTTP ", status, ": ", substr(body, 1L, 512L))
    )
  }
  tryCatch(
    json_parse(body),
    error = function(error) praxo_error("PROVIDER_JSON", "provider returned invalid JSON")
  )
}
