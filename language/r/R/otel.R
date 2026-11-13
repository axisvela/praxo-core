otel_sink <- function(endpoint = "http://127.0.0.1:4318/v1/traces",
                      service_name = "praxo-core", transport = NULL,
                      allowed_data_keys = character()) {
  sink <- list(
    endpoint = if (is.null(endpoint) || !nzchar(endpoint)) {
      "http://127.0.0.1:4318/v1/traces"
    } else {
      endpoint
    },
    serviceName = if (is.null(service_name) || !nzchar(service_name)) {
      "praxo-core"
    } else {
      service_name
    },
    allowedDataKeys = as.character(allowed_data_keys),
    transport = transport
  )
  sink$emit <- function(event) otel_emit(sink, event)
  sink
}

otel_emit <- function(sink, event) {
  attributes <- list(otel_attribute("praxo.event.type", event$type))
  if (!is.null(event$sessionId) && nzchar(event$sessionId)) {
    attributes[[length(attributes) + 1L]] <-
      otel_attribute("praxo.session.id", event$sessionId)
  }
  if (!is.null(event$runId) && nzchar(event$runId)) {
    attributes[[length(attributes) + 1L]] <-
      otel_attribute("praxo.run.id", event$runId)
  }
  stamp <- if (!is.null(event$at) && nzchar(event$at)) {
    event$at
  } else {
    format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  attributes[[length(attributes) + 1L]] <-
    otel_attribute("praxo.event.at", stamp)
  if (is.list(event$data) && length(sink$allowedDataKeys) > 0L) {
    for (name in sink$allowedDataKeys) {
      if (name %in% names(event$data)) {
        attributes[[length(attributes) + 1L]] <- otel_attribute(
          paste0("praxo.event.data.", name),
          otel_text(event$data[[name]])
        )
      }
    }
  }
  data <- if (is.list(event$data)) json_encode(event$data) else "{}"
  key <- paste(event$sessionId %||% "", event$runId %||% "", event$type,
               stamp, data, sep = "|")
  trace_id <- paste0(
    otel_hex32(otel_hash32(key, 2166136261)),
    otel_hex32(otel_hash32(key, 3307539480)),
    otel_hex32(otel_hash32(key, 1540483477)),
    otel_hex32(otel_hash32(key, 2807494644))
  )
  span_id <- paste0(
    otel_hex32(otel_hash32(paste0(key, "|span"), 2166136261)),
    otel_hex32(otel_hash32(paste0(key, "|span"), 3307539480))
  )
  nanos <- sprintf("%.0f", as.numeric(Sys.time()) * 1e9)
  payload <- list(resourceSpans = list(list(
    resource = list(attributes = list(
      otel_attribute("service.name", sink$serviceName)
    )),
    scopeSpans = list(list(
      scope = list(name = "praxo-core"),
      spans = list(list(
        traceId = trace_id,
        spanId = span_id,
        name = paste0("praxo.", event$type),
        kind = 1L,
        startTimeUnixNano = nanos,
        endTimeUnixNano = nanos,
        attributes = attributes
      ))
    ))
  )))
  body <- json_encode(payload)
  response <- if (!is.null(sink$transport)) {
    sink$transport(sink$endpoint, body)
  } else {
    otel_post(sink, body)
  }
  status <- as.integer(response$status %||% 0L)
  if (status < 200L || status >= 300L) {
    message <- response$body %||% ""
    praxo_error("OTEL_HTTP",
                paste0("otel: HTTP ", status, ": ",
                       substr(message, 1L, 512L)))
  }
  invisible(NULL)
}

otel_attribute <- function(key, value) {
  list(key = key, value = list(stringValue = as.character(value)))
}

otel_text <- function(value) {
  if (is.character(value)) as.character(value) else json_encode(value)
}

otel_hash32 <- function(text, seed) {
  value <- seed %% 4294967296
  for (code in utf8ToInt(enc2utf8(text))) {
    value <- (value + code) %% 4294967296
    value <- (value * 16777619) %% 4294967296
  }
  value
}

otel_hex32 <- function(value) {
  value <- value %% 4294967296
  digits <- character(8L)
  alphabet <- c("0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                "a", "b", "c", "d", "e", "f")
  for (index in 8:1) {
    digits[index] <- alphabet[(value %% 16) + 1]
    value <- value %/% 16
  }
  paste0(digits, collapse = "")
}

otel_post <- function(sink, body) {
  input <- tempfile()
  output <- tempfile()
  on.exit(unlink(c(input, output)), add = TRUE)
  writeLines(body, input, useBytes = TRUE)
  args <- c("-sS", "-X", "POST", "-H", "content-type: application/json",
            "--data-binary", paste0("@", input), "-o", output,
            "-w", "%{http_code}", sink$endpoint)
  status_text <- tryCatch(
    suppressWarnings(system2("curl", args, stdout = TRUE, stderr = FALSE)),
    error = function(error) character()
  )
  status <- suppressWarnings(as.integer(tail(status_text, 1L)))
  if (is.na(status)) {
    praxo_error("OTEL_HTTP", "otel: request failed")
  }
  response_body <- if (file.exists(output)) {
    paste(readLines(output, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  list(status = status, body = response_body)
}
