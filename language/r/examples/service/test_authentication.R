args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grep("^--file=", args)]
script <- if (length(script_arg)) sub("^--file=", "", script_arg[1]) else ""
service_dir <- if (nzchar(script)) dirname(normalizePath(script)) else getwd()
source(file.path(service_dir, "..", "..", "R", "json.R"))
source(file.path(service_dir, "authentication.R"))

scripted <- function(status = 200L, body = "{}") {
  state <- new.env(parent = emptyenv())
  state$status <- status
  state$body <- body
  state$unavailable <- FALSE
  state$forms <- list()
  state$authorizations <- list()
  post <- function(url, form, authorization) {
    state$forms <- c(state$forms, list(form))
    state$authorizations <- c(state$authorizations, list(authorization))
    if (state$unavailable) stop("identity provider unavailable")
    list(status = state$status, body = state$body)
  }
  list(post = post, state = state)
}

expect_auth_error <- function(expression) {
  error <- tryCatch(
    {
      force(expression)
      NULL
    },
    error = function(caught) caught
  )
  stopifnot(inherits(error, "service_auth_error"))
}

now <- 1700000000L
endpoint <- "https://id.example.com/introspect"
revocation_endpoint <- "https://id.example.com/revoke"

body_with <- function(...) json_encode(list(...))

active_body <- body_with(
  active = TRUE, sub = "user-1", tenant = "local", exp = now + 60
)
active <- scripted(200L, active_body)
authenticator <- introspection_authenticator(
  active$post, endpoint, "client", "secret"
)
principal <- authenticate(authenticator, "Bearer opaque-token", now)
stopifnot(!is.null(principal))
stopifnot(identical(principal$subject, "user-1"))
stopifnot(identical(principal$tenant, "local"))
stopifnot(principal$expires == now + 60)
stopifnot(identical(active$state$forms[[1]]$token, "opaque-token"))
stopifnot(identical(active$state$forms[[1]]$client_id, "client"))
stopifnot(identical(active$state$forms[[1]]$client_secret, "secret"))
stopifnot(identical(active$state$authorizations[[1]], "Basic Y2xpZW50OnNlY3JldA=="))

blank <- scripted(200L, active_body)
blank_authenticator <- introspection_authenticator(blank$post, endpoint)
stopifnot(!is.null(authenticate(blank_authenticator, "Bearer opaque-token", now)))
stopifnot(is.null(blank$state$authorizations[[1]]))

for (value in list(
  NULL, "", "Bearer", "Basic abc", "bearer token", "Token abc",
  "Bearer ", "Bearer    "
)) {
  stopifnot(is.null(authenticate(authenticator, value, now)))
}

reject <- function(body, tenant_claim = "tenant", status = 200L,
                   unavailable = FALSE) {
  transport <- scripted(status, body)
  transport$state$unavailable <- unavailable
  candidate <- introspection_authenticator(
    transport$post, endpoint, tenant_claim = tenant_claim
  )
  stopifnot(is.null(authenticate(candidate, "Bearer opaque-token", now)))
}

reject(body_with(active = FALSE))
reject(body_with(active = TRUE, tenant = "local", exp = now + 60))
reject(body_with(active = TRUE, sub = "", tenant = "local", exp = now + 60))
reject(body_with(active = TRUE, sub = "user-1", exp = now + 60))
reject(body_with(
  active = TRUE, sub = "user-1", tenant = "", exp = now + 60
))
reject(body_with(active = TRUE, sub = "user-1", tenant = "local", exp = now))
reject(body_with(
  active = TRUE, sub = "user-1", tenant = "local", exp = now - 1
))
reject("{not json")
reject(body_with(active = TRUE), status = 401L)
reject("{}", unavailable = TRUE)

custom_body <- body_with(
  active = TRUE, sub = "user-1", org = "acme", exp = now + 60
)
custom_transport <- scripted(200L, custom_body)
custom_authenticator <- introspection_authenticator(
  custom_transport$post, endpoint, tenant_claim = "org"
)
custom_principal <- authenticate(custom_authenticator, "Bearer opaque-token", now)
stopifnot(!is.null(custom_principal))
stopifnot(identical(custom_principal$tenant, "acme"))

revocation <- scripted(200L, "{}")
revoker <- revocation_client(
  revocation$post, revocation_endpoint, "client", "secret"
)
stopifnot(isTRUE(revoke(revoker, "opaque-token")))
stopifnot(identical(revocation$state$forms[[1]]$token, "opaque-token"))
stopifnot(identical(
  revocation$state$forms[[1]]$token_type_hint, "access_token"
))

failed_revocation <- scripted(503L, "{}")
expect_auth_error(revoke(
  revocation_client(failed_revocation$post, revocation_endpoint), "opaque-token"
))

unavailable_revocation <- scripted(200L, "{}")
unavailable_revocation$state$unavailable <- TRUE
expect_auth_error(revoke(
  revocation_client(unavailable_revocation$post, revocation_endpoint),
  "opaque-token"
))

expect_auth_error(revoke(revoker, ""))

cat("R service auth tests passed\n")
