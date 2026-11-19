provider_request <- function() {
  request(
    messages = list(
      message(roles$system, "be brief"),
      message(roles$user, "hi")
    ),
    tools = list(tool_spec("echo", "Echo", list(type = "object"))),
    tool_choice = "auto"
  )
}

anthropic_test <- function() {
  captured <- NULL
  adapter <- anthropic(
    model = "claude-test",
    api_key = "ak",
    transport = function(path, payload) {
      captured <<- list(path = path, payload = payload)
      list(
        content = list(
          list(type = "text", text = "hello"),
          list(type = "tool_use", id = "tool-1", name = "echo",
               input = list(text = "hi"))
        ),
        stop_reason = "end_turn",
        usage = list(input_tokens = 3L, output_tokens = 4L,
                     cache_read_input_tokens = 2L)
      )
    }
  )
  result <- anthropic_generate(adapter, provider_request())
  stopifnot(identical(captured$path, "/v1/messages"))
  stopifnot(identical(captured$payload$system, "be brief"))
  stopifnot(identical(captured$payload$tool_choice$type, "auto"))
  stopifnot(identical(captured$payload$tools[[1L]]$input_schema$type, "object"))
  stopifnot(identical(result$message$content, "hello"))
  stopifnot(identical(result$message$toolCalls[[1L]]$arguments$text, "hi"))
  stopifnot(identical(result$usage$cachedTokens, 2L))
  stopifnot(identical(result$finishReason, "end_turn"))

  error <- tryCatch(
    anthropic_generate(anthropic(model = "m"), provider_request()),
    error = function(error) error
  )
  stopifnot(inherits(error, "praxo_error"))
  stopifnot(identical(error$code, "PROVIDER_CONFIG"))
}

gemini_test <- function() {
  captured <- NULL
  adapter <- gemini(
    model = "gemini-test",
    api_key = "gk",
    transport = function(path, payload) {
      captured <<- list(path = path, payload = payload)
      list(
        candidates = list(list(
          content = list(parts = list(
            list(text = "hello"),
            list(functionCall = list(name = "echo", args = list(text = "hi")))
          )),
          finishReason = "STOP"
        )),
        usageMetadata = list(
          promptTokenCount = 3L,
          candidatesTokenCount = 4L,
          cachedContentTokenCount = 2L
        )
      )
    }
  )
  result <- gemini_generate(adapter, provider_request())
  stopifnot(grepl(":generateContent$", captured$path))
  stopifnot(identical(
    captured$payload$system_instruction$parts[[1L]]$text,
    "be brief"
  ))
  stopifnot(identical(
    captured$payload$toolConfig$functionCallingConfig$mode,
    "AUTO"
  ))
  stopifnot(identical(result$message$content, "hello"))
  stopifnot(identical(result$message$toolCalls[[1L]]$name, "echo"))
  stopifnot(identical(result$usage$cachedTokens, 2L))
  stopifnot(identical(result$finishReason, "STOP"))

  stream_captured <- NULL
  stream_adapter <- gemini(
    model = "gemini-test",
    api_key = "gk",
    stream_transport = function(path, payload) {
      stream_captured <<- list(path = path, payload = payload)
      paste(
        'data: {"candidates":[{"content":{"parts":[{"text":"he"}]}}]}',
        'data: {"candidates":[{"content":{"parts":[{"text":"llo"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":4,"candidatesTokenCount":2,"cachedContentTokenCount":1}}',
        sep = "\n\n"
      )
    }
  )
  deltas <- character()
  stream_result <- gemini_stream_generate(
    stream_adapter,
    provider_request(),
    function(delta) deltas <<- c(deltas, delta)
  )
  stopifnot(grepl(":streamGenerateContent", stream_captured$path))
  stopifnot(grepl("alt=sse", stream_captured$path))
  stopifnot(identical(deltas, c("he", "llo")))
  stopifnot(identical(stream_result$message$content, "hello"))
  stopifnot(identical(stream_result$message$toolCalls[[1L]]$name, "echo"))
  stopifnot(identical(stream_result$message$toolCalls[[1L]]$arguments$text, "hi"))
  stopifnot(identical(stream_result$usage$inputTokens, 4L))
  stopifnot(identical(stream_result$usage$outputTokens, 2L))
  stopifnot(identical(stream_result$usage$cachedTokens, 1L))
  stopifnot(identical(stream_result$finishReason, "STOP"))

  error <- tryCatch(
    gemini_generate(gemini(model = "m"), provider_request()),
    error = function(error) error
  )
  stopifnot(inherits(error, "praxo_error"))
  stopifnot(identical(error$code, "PROVIDER_CONFIG"))
}

anthropic_test()
gemini_test()
