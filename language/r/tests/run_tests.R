args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grep("^--file=", args)]
script <- sub("^--file=", "", script_arg[1])
root <- normalizePath(file.path(dirname(script), "..", "..", ".."))
source(file.path(root, "language", "r", "R", "json.R"))
source(file.path(root, "language", "r", "R", "toolcall.R"))
source(file.path(root, "language", "r", "R", "jsonschema.R"))
source(file.path(root, "language", "r", "R", "plugin.R"))
source(file.path(root, "language", "r", "R", "core.R"))

expect_code <- function(expr, code) {
  error <- tryCatch({ force(expr); NULL }, error = function(e) e)
  stopifnot(inherits(error, "praxo_error"), identical(error$code, code))
}

call <- toolcall_parse('{"name":"echo","input":{"text":"hi"}}')
stopifnot(!is.null(call), identical(call$name, "echo"), identical(call$input$text, "hi"))
stopifnot(identical(
  toolcall_strip('hello<tool_call name="echo">{"text":"hi"}</tool_call>world'),
  "helloworld"
))
schema <- json_parse('{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}')
errors <- schema_validate(schema, json_parse("{}"))
stopifnot(length(errors) == 1L, identical(errors[[1]]$path, "$.name"))
manifest <- plugin_parse_manifest('{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},"health":{},"isolation":"process"}')
stopifnot(identical(manifest$id, "com.example.echo"))

integer_schema <- json_parse('{"type":"integer"}')
stopifnot(length(schema_validate(integer_schema, 2.5)) == 1L)
unicode_schema <- json_parse('{"type":"string","minLength":2,"maxLength":2}')
stopifnot(length(schema_validate(unicode_schema, "你好")) == 0L)
stopifnot(length(schema_validate(unicode_schema, "你")) == 1L)

limit <- call_limit(1L, 1L)
stopifnot(is.null(call_limit_model(limit)))
expect_code(call_limit_model(limit), "AGENT_MODEL_CALL_LIMIT")
stopifnot(is.null(call_limit_tool(limit)))
expect_code(call_limit_tool(limit), "AGENT_TOOL_CALL_LIMIT")

first_run <- call_limit(1L, 0L)
second_run <- call_limit(1L, 0L)
stopifnot(is.null(call_limit_model(first_run)))
stopifnot(is.null(call_limit_model(second_run)))
expect_code(call_limit_model(first_run), "AGENT_MODEL_CALL_LIMIT")

history <- list(messages = list(list(
  content = "email a@b.com",
  toolCalls = list(list(arguments = list(
    email = "a@b.com",
    nested = list(ssn = "123-45-6789")
  )))
)))
redacted <- redact_value(history)
stopifnot(identical(
  redacted$messages[[1L]]$toolCalls[[1L]]$arguments$email,
  "[REDACTED:email]"
))
stopifnot(identical(
  redacted$messages[[1L]]$toolCalls[[1L]]$arguments$nested$ssn,
  "[REDACTED:ssn]"
))
stopifnot(identical(
  history$messages[[1L]]$toolCalls[[1L]]$arguments$email,
  "a@b.com"
))

allow <- checkpoint_allowlist()
checkpoint_register(allow, "spec.payload")
encoded <- checkpoint_marshal(allow, "spec.payload", list(value = "x"))
decoded <- checkpoint_unmarshal(allow, encoded)
stopifnot(identical(decoded$value, "x"))

capacity <- context_budget(2L, 0L)
compacted <- compact_context(capacity, list(message(roles$system, strrep("x", 1000L))))
stopifnot(identical(compacted[[2L]], FALSE))

cat("R core tests passed\n")
