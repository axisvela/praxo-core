if (!exists("json_parse", mode = "function")) {
  stop("source language/r/R/json.R before authentication.R")
}

auth_error <- function(message) {
  structure(
    list(message = message),
    class = c("service_auth_error", "error", "condition")
  )
}

auth_principal <- function(subject, tenant, expires) {
  structure(
    list(subject = subject, tenant = tenant, expires = expires),
    class = "service_principal"
  )
}

base64_encode <- function(text) {
  bytes <- as.integer(charToRaw(enc2utf8(text)))
  if (length(bytes) == 0L) return("")
  alphabet <- strsplit(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
    "",
    fixed = TRUE
  )[[1]]
  out <- character()
  for (offset in seq(1L, length(bytes), by = 3L)) {
    chunk <- bytes[offset:min(offset + 2L, length(bytes))]
    chunk <- c(chunk, rep(0L, 3L - length(chunk)))
    value <- bitwShiftL(chunk[1], 16L) + bitwShiftL(chunk[2], 8L) + chunk[3]
    out <- c(
      out,
      alphabet[bitwAnd(bitwShiftR(value, 18L), 63L) + 1L],
      alphabet[bitwAnd(bitwShiftR(value, 12L), 63L) + 1L],
      alphabet[bitwAnd(bitwShiftR(value, 6L), 63L) + 1L],
      alphabet[bitwAnd(value, 63L) + 1L]
    )
  }
  padding <- (3L - length(bytes) %% 3L) %% 3L
  if (padding > 0L) {
    out[(length(out) - padding + 1L):length(out)] <- "="
  }
  paste(out, collapse = "")
}

basic_auth <- function(client_id, client_secret) {
  if (!nzchar(client_id)) return(NULL)
  paste0("Basic ", base64_encode(paste0(client_id, ":", client_secret)))
}

introspection_authenticator <- function(
  transport,
  endpoint,
  client_id = "",
  client_secret = "",
  tenant_claim = "tenant"
) {
  claim <- if (nzchar(tenant_claim)) tenant_claim else "tenant"
  structure(
    list(
      transport = transport,
      endpoint = endpoint,
      client_id = client_id,
      client_secret = client_secret,
      tenant_claim = claim
    ),
    class = "service_introspection_authenticator"
  )
}

authenticate <- function(authenticator, authorization, now) {
  if (is.null(authorization) || !is.character(authorization) ||
      length(authorization) != 1L || is.na(authorization)) {
    return(NULL)
  }
  if (!startsWith(authorization, "Bearer ")) return(NULL)
  token <- trimws(substring(authorization, 8L))
  if (!nzchar(token)) return(NULL)
  form <- list(
    token = token,
    client_id = authenticator$client_id,
    client_secret = authenticator$client_secret
  )
  response <- tryCatch(
    authenticator$transport(
      authenticator$endpoint,
      form,
      basic_auth(authenticator$client_id, authenticator$client_secret)
    ),
    error = function(error) NULL
  )
  if (is.null(response) || !is.list(response) ||
      is.null(response$status) || is.null(response$body)) {
    return(NULL)
  }
  status <- response$status
  body <- response$body
  if (!is.numeric(status) || length(status) != 1L || is.na(status) ||
      status != 200) {
    return(NULL)
  }
  if (!is.character(body) || length(body) != 1L || is.na(body)) return(NULL)
  payload <- tryCatch(json_parse(body), error = function(error) NULL)
  if (is.null(payload) || !is.list(payload) || is.null(names(payload))) {
    return(NULL)
  }
  if (!identical(json_bool(payload, "active", FALSE), TRUE)) return(NULL)
  subject <- json_string(payload, "sub", NULL)
  tenant <- json_string(payload, authenticator$tenant_claim, NULL)
  if (is.null(subject) || !nzchar(subject)) return(NULL)
  if (is.null(tenant) || !nzchar(tenant)) return(NULL)
  expires <- json_get(payload, "exp", NULL)
  if (is.null(expires) || !is.numeric(expires) || length(expires) != 1L ||
      !is.finite(expires) || expires != floor(expires) || expires <= now) {
    return(NULL)
  }
  auth_principal(subject, tenant, expires)
}

revocation_client <- function(
  transport,
  endpoint,
  client_id = "",
  client_secret = ""
) {
  structure(
    list(
      transport = transport,
      endpoint = endpoint,
      client_id = client_id,
      client_secret = client_secret
    ),
    class = "service_revocation_client"
  )
}

revoke <- function(client, token) {
  if (is.null(token) || !is.character(token) || length(token) != 1L ||
      is.na(token) || !nzchar(token)) {
    stop(auth_error("revocation token is required"))
  }
  form <- list(
    token = token,
    token_type_hint = "access_token",
    client_id = client$client_id,
    client_secret = client$client_secret
  )
  response <- tryCatch(
    client$transport(
      client$endpoint,
      form,
      basic_auth(client$client_id, client$client_secret)
    ),
    error = function(error) stop(auth_error("token revocation failed"))
  )
  if (!is.list(response) || is.null(response$status)) {
    stop(auth_error("token revocation failed"))
  }
  status <- response$status
  if (!is.numeric(status) || length(status) != 1L || is.na(status) ||
      status != 200) {
    stop(auth_error("token revocation failed"))
  }
  TRUE
}
