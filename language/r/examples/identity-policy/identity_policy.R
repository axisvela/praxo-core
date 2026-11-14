authorize <- function(principal, action) {
  if (is.null(principal)) return(FALSE)
  if (!principal$active) return(FALSE)
  if (identical(action$kind, "model.generate")) return(TRUE)
  if (!identical(principal$role, "operator")) return(FALSE)
  if (!identical(action$tenant, principal$tenant)) return(FALSE)
  if (!identical(action$tool, "record")) return(FALSE)
  TRUE
}

operator <- list(tenant = "acme", role = "operator", active = TRUE)
stopifnot(authorize(operator, list(kind = "model.generate")))
stopifnot(authorize(operator, list(kind = "tool.invoke", tool = "record", tenant = "acme")))
stopifnot(!authorize(list(tenant = "acme", role = "viewer", active = TRUE),
                     list(kind = "tool.invoke", tool = "record", tenant = "acme")))
stopifnot(!authorize(operator, list(kind = "tool.invoke", tool = "record", tenant = "other")))
stopifnot(!authorize(NULL, list(kind = "model.generate")))

cat("R identity policy example passed\n")
