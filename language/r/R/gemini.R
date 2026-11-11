gemini <- function(base_url = "https://generativelanguage.googleapis.com",
                   model = "",
                   api_key = NULL,
                   transport = NULL,
                   timeout = 60,
                   max_output_tokens = 0L) {
  list(
    baseUrl = sub("/+$", "", if (is.null(base_url)) "" else base_url),
    model = if (is.null(model)) "" else model,
    apiKey = api_key,
    transport = transport,
    timeout = timeout,
    maxOutputTokens = max_output_tokens
  )
}

gemini_message_parts <- function(value) {
  parts <- list()
  if (!is.null(value$content) && nzchar(value$content)) {
    parts[[length(parts) + 1L]] <- list(text = value$content)
  }
  for (block in value$contentBlocks %||% list()) {
    if (identical(block$type, "text") && !is.null(block$text)) {
      parts[[length(parts) + 1L]] <- list(text = block$text)
    }
  }
  for (call in value$toolCalls %||% list()) {
    parts[[length(parts) + 1L]] <- list(
      functionCall = list(
        name = call$name %||% "",
        args = openai_compatible_object(call$arguments)
      )
    )
  }
  parts
}

gemini_payload <- function(adapter, request) {
  system_parts <- list()
  contents <- list()
  tool_parts <- list()
  names <- list()
  flush <- function() {
    if (length(tool_parts) > 0L) {
      contents[[length(contents) + 1L]] <<- list(
        role = "user",
        parts = tool_parts
      )
      tool_parts <<- list()
    }
  }
  for (value in request$messages %||% list()) {
    if (identical(value$role, roles$system)) {
      if (!is.null(value$content) && nzchar(value$content)) {
        system_parts[[length(system_parts) + 1L]] <- list(text = value$content)
      }
      next
    }
    if (identical(value$role, roles$tool)) {
      name <- names[[value$toolId %||% ""]] %||% value$toolId %||% "tool"
      tool_parts[[length(tool_parts) + 1L]] <- list(
        functionResponse = list(
          name = name,
          response = list(result = value$content %||% "")
        )
      )
      next
    }
    flush()
    parts <- gemini_message_parts(value)
    if (length(parts) > 0L) {
      contents[[length(contents) + 1L]] <- list(
        role = if (identical(value$role, roles$assistant)) "model" else "user",
        parts = parts
      )
    }
    for (call in value$toolCalls %||% list()) {
      if (nzchar(call$id %||% "") && nzchar(call$name %||% "")) {
        names[[call$id]] <- call$name
      }
    }
  }
  flush()
  payload <- list(contents = contents)
  if (length(system_parts) > 0L) {
    payload$system_instruction <- list(parts = system_parts)
  }
  tools <- request$tools %||% list()
  if (length(tools) > 0L) {
    payload$tools <- list(list(
      functionDeclarations = lapply(tools, function(tool) {
        list(
          name = tool$name,
          description = tool$description %||% "",
          parameters = openai_compatible_object(
            tool$parameters %||% list(type = "object")
          )
        )
      })
    ))
    payload$toolConfig <- list(
      functionCallingConfig = list(
        mode = gemini_tool_mode(request$toolChoice)
      )
    )
  }
  if ((!is.null(request$temperature) && request$temperature != 0) ||
      adapter$maxOutputTokens > 0L) {
    payload$generationConfig <- list(
      temperature = request$temperature %||% 0,
      maxOutputTokens = adapter$maxOutputTokens
    )
  }
  payload
}

gemini_tool_mode <- function(choice) {
  if (identical(choice, "required")) return("ANY")
  if (identical(choice, "none")) return("NONE")
  "AUTO"
}

gemini_parse_response <- function(data) {
  error <- data$error
  if (!is.null(error)) {
    praxo_error("PROVIDER_HTTP", paste0("gemini: ", error$message %||% "error"))
  }
  candidates <- data$candidates %||% list()
  if (length(candidates) == 0L) {
    praxo_error("PROVIDER_HTTP", "gemini: empty response")
  }
  candidate <- candidates[[1L]]
  text <- character()
  calls <- list()
  for (part in json_get(candidate, "content", list())$parts %||% list()) {
    if (!is.null(part$text)) text <- c(text, part$text)
    call <- part$functionCall
    if (!is.null(call)) {
      calls[[length(calls) + 1L]] <- tool_call(
        paste0("call-", length(calls) + 1L),
        call$name %||% "",
        openai_compatible_object(call$args)
      )
    }
  }
  usage_value <- data$usageMetadata %||% list()
  result <- response(
    message(roles$assistant, paste0(text, collapse = ""), tool_calls = calls),
    usage(
      usage_value$promptTokenCount %||% 0L,
      usage_value$candidatesTokenCount %||% 0L
    )
  )
  result$usage$cachedTokens <- usage_value$cachedContentTokenCount %||% 0L
  result$finishReason <- candidate$finishReason
  result
}

gemini_generate <- function(adapter, request) {
  if (is.null(adapter$apiKey) || !nzchar(adapter$apiKey)) {
    praxo_error("PROVIDER_CONFIG", "gemini: API key is required")
  }
  if (!nzchar(adapter$model)) {
    praxo_error("PROVIDER_CONFIG", "gemini: model is required")
  }
  path <- paste0(
    "/v1beta/models/",
    utils::URLencode(adapter$model, reserved = TRUE),
    ":generateContent"
  )
  payload <- gemini_payload(adapter, request)
  data <- if (!is.null(adapter$transport)) {
    adapter$transport(path, payload)
  } else {
    gemini_post(adapter, path, payload)
  }
  gemini_parse_response(data)
}

gemini_model <- function(adapter) {
  function(request) gemini_generate(adapter, request)
}

gemini_post <- function(adapter, path, payload) {
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
    "-H", paste0("x-goog-api-key: ", adapter$apiKey),
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
