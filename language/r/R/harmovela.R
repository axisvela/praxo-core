harmovela_sink <- function(base_url, source = "praxo-core", spec_version = "0.2",
                           transport = NULL) {
  sink <- list(
    baseUrl = sub("/+$", "", if (is.null(base_url)) "" else base_url),
    source = if (is.null(source) || !nzchar(source)) "praxo-core" else source,
    specVersion = if (is.null(spec_version) || !nzchar(spec_version)) "0.2" else spec_version,
    transport = transport
  )
  sink$emit <- function(event) harmovela_emit(sink, event)
  sink
}

harmovela_emit <- function(sink, event) {
  if (!nzchar(sink$baseUrl)) {
    praxo_error("HARMOVELA_BASE_URL", "harmovela: base URL is required")
  }
  payload <- event$data
  if (is.null(payload) || !is.list(payload)) payload <- list()
  if (is.null(names(payload))) names(payload) <- character(0)
  if (!is.null(event$sessionId) && nzchar(event$sessionId)) {
    payload$session_id <- event$sessionId
  }
  if (!is.null(event$runId) && nzchar(event$runId)) {
    payload$run_id <- event$runId
  }
  stamp <- harmovela_stamp()
  envelope <- list(
    spec_version = sink$specVersion,
    id = paste0(harmovela_prefix(event), "-", stamp$id),
    type = event$type,
    source = sink$source,
    created_at = stamp$createdAt,
    payload = payload
  )
  response <- if (!is.null(sink$transport)) {
    sink$transport("/events", envelope)
  } else {
    harmovela_post(sink, envelope)
  }
  status <- as.integer(response$status %||% 0L)
  body <- response$body %||% ""
  if (status < 200L || status >= 300L) {
    praxo_error("HARMOVELA_HTTP",
                paste0("harmovela: HTTP ", status, ": ", substr(body, 1L, 512L)))
  }
  invisible(NULL)
}

harmovela_prefix <- function(event) {
  if (!is.null(event$runId) && nzchar(event$runId)) return(event$runId)
  if (!is.null(event$sessionId) && nzchar(event$sessionId)) return(event$sessionId)
  "event"
}

harmovela_stamp <- function() {
  now <- as.numeric(Sys.time())
  whole <- floor(now)
  nanos <- as.integer(round((now - whole) * 1e9))
  if (nanos >= 1000000000L) {
    whole <- whole + 1
    nanos <- 0L
  }
  created_at <- paste0(
    format(as.POSIXct(whole, origin = "1970-01-01", tz = "UTC"),
           "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
    ".", sprintf("%09d", nanos), "Z"
  )
  list(
    createdAt = created_at,
    id = paste0(format(whole, scientific = FALSE, trim = TRUE),
                sprintf("%09d", nanos))
  )
}

harmovela_post <- function(sink, envelope) {
  input <- tempfile()
  output <- tempfile()
  on.exit(unlink(c(input, output)), add = TRUE)
  writeLines(json_encode(envelope), input, useBytes = TRUE)
  args <- c("-sS", "-X", "POST", "-H", "content-type: application/json",
            "--data-binary", paste0("@", input), "-o", output,
            "-w", "%{http_code}", paste0(sink$baseUrl, "/events"))
  status_text <- tryCatch(
    suppressWarnings(system2("curl", args, stdout = TRUE, stderr = FALSE)),
    error = function(error) character()
  )
  status <- suppressWarnings(as.integer(tail(status_text, 1L)))
  if (is.na(status)) {
    praxo_error("HARMOVELA_HTTP", "harmovela: request failed")
  }
  body <- if (file.exists(output)) {
    paste(readLines(output, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  list(status = status, body = body)
}
