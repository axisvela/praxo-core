source("language/r/R/json.R")
source("language/r/R/core.R")

allow <- checkpoint_allowlist()
checkpoint_register(allow, "order")
encoded <- checkpoint_marshal(allow, "order", list(value = "x"))
decoded <- checkpoint_unmarshal(allow, encoded)
stopifnot(identical(decoded$value, "x"))

error <- tryCatch(
  {
    checkpoint_marshal(allow, "missing", list())
    NULL
  },
  praxo_error = function(condition) condition
)
stopifnot(!is.null(error), error_code(error) == "CHECKPOINT_TYPE_NOT_ALLOWED")

cat("R checkpoint example passed\n")
