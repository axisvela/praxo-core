handle <- function(method, path, principal, body) {
  if (identical(method, "GET") && identical(path, "/healthz")) {
    return(list(status = 200L, body = list(status = "ok")))
  }
  if (!identical(method, "POST") || !identical(path, "/run")) {
    return(list(status = 404L, body = list(error = "not found")))
  }
  if (is.null(principal) || !nzchar(principal)) {
    return(list(status = 401L, body = list(error = "missing X-Praxo-Principal")))
  }
  if (!grepl('"prompt"', body, fixed = TRUE)) {
    return(list(status = 400L, body = list(error = "prompt is required")))
  }
  list(status = 200L, body = list(output = "hello from the service"))
}

health <- handle("GET", "/healthz", NULL, "")
stopifnot(health$status == 200L, identical(health$body$status, "ok"))
unauthorized <- handle("POST", "/run", NULL, '{"prompt":"hi"}')
stopifnot(unauthorized$status == 401L)
ok <- handle("POST", "/run", "user-1", '{"prompt":"hi"}')
stopifnot(ok$status == 200L, identical(ok$body$output, "hello from the service"))

cat("R service example passed\n")
