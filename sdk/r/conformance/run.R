args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grep("^--file=", args)]
script <- sub("^--file=", "", script_arg[1])
root <- normalizePath(file.path(dirname(script), "..", "..", ".."))

source(file.path(root, "sdk", "r", "R", "json.R"))
source(file.path(root, "sdk", "r", "R", "toolcall.R"))
source(file.path(root, "sdk", "r", "R", "jsonschema.R"))
source(file.path(root, "sdk", "r", "R", "plugin.R"))
source(file.path(root, "sdk", "r", "R", "core.R"))
source(file.path(root, "sdk", "r", "conformance", "core.R"))

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

check <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

run_toolcall <- function(input, expect) {
  operation <- json_string(input, "operation", "")
  content <- json_string(input, "content", "")
  if (identical(operation, "strip")) {
    got <- toolcall_strip(content)
    check(identical(got, json_string(expect, "text", "")), paste0("strip: got ", got))
    return(invisible(NULL))
  }
  call <- toolcall_parse(content)
  if (isTRUE(json_bool(expect, "nil", FALSE))) {
    check(is.null(call), "expected nil")
    return(invisible(NULL))
  }
  check(!is.null(call), "expected a tool call")
  check(identical(call$name, json_string(expect, "name", "")), paste0("name: got ", call$name))
  expected <- json_get(expect, "input", list())
  check(json_equals(call$input, expected), "input mismatch")
}

run_jsonschema <- function(input, expect) {
  errors <- schema_validate(json_get(input, "schema", list()), json_get(input, "data", NULL))
  paths <- sort(vapply(errors, function(error) error$path, character(1)))
  expected <- sort(unlist(json_array(expect, "errorPaths"), use.names = FALSE))
  if (length(expected) == 0L) expected <- character()
  check(identical(length(errors) == 0L, isTRUE(json_bool(expect, "valid", FALSE))), "valid mismatch")
  check(identical(paths, expected), paste0("errorPaths: got ", paste(paths, collapse = ", ")))
}

run_plugin <- function(input, expect) {
  raw <- json_string(input, "raw", NULL)
  if (is.null(raw)) raw <- json_encode(json_get(input, "manifest", list()))
  manifest <- tryCatch(plugin_parse_manifest(raw), error = function(e) NULL)
  check(identical(!is.null(manifest), isTRUE(json_bool(expect, "valid", FALSE))), "valid mismatch")
  if (is.null(manifest)) return(invisible(NULL))
  id <- json_string(expect, "id", NULL)
  if (!is.null(id)) check(identical(manifest$id, id), paste0("id: got ", manifest$id))
  kind <- json_string(expect, "kind", NULL)
  if (!is.null(kind)) check(identical(manifest$kind, kind), paste0("kind: got ", manifest$kind))
}

run_vector <- function(group, vector) {
  input <- json_get(vector, "input", list())
  expect <- json_get(vector, "expect", list())
  if (group == "toolcall") run_toolcall(input, expect)
  if (group == "jsonschema") run_jsonschema(input, expect)
  if (group == "plugin") run_plugin(input, expect)
  if (group == "memory") run_memory(input, expect)
  if (group == "event") run_event(input, expect)
  if (group == "stream") run_stream(expect)
  if (group == "checkpoint") run_checkpoint(input, expect)
  if (group == "policy") run_policy(input, expect)
  if (group == "context") run_context(input, expect)
  if (group == "middleware") run_middleware(input, expect)
  if (group == "agent-loop") run_agent_loop(input, expect)
}

version <- trimws(read_text(file.path(root, "spec", "SPEC_VERSION")))
files <- sort(list.files(file.path(root, "spec", "vectors"), pattern = "\\.json$", full.names = TRUE))
wire_groups <- c("toolcall", "jsonschema", "plugin")
failures <- character()
seen <- list()

for (path in files) {
  name <- sub("\\.json$", "", basename(path))
  file <- tryCatch(json_parse(read_text(path)), error = function(e) NULL)
  if (is.null(file)) {
    failures <- c(failures, paste0(name, ": invalid vector file"))
    next
  }
  group <- json_string(file, "group", "")
  if (!identical(json_string(file, "specVersion", ""), version)) failures <- c(failures, paste0(name, ": specVersion mismatch"))
  if (!identical(name, group)) failures <- c(failures, paste0(name, ": group mismatch"))
  for (vector in json_array(file, "vectors")) {
    id <- json_string(vector, "id", "")
    if (!is.null(seen[[id]])) failures <- c(failures, paste0(group, "/", id, ": duplicate id with ", seen[[id]]))
    seen[[id]] <- group
    result <- tryCatch({ run_vector(group, vector); NULL }, error = function(e) conditionMessage(e))
    if (!is.null(result)) failures <- c(failures, paste0(group, "/", id, ": ", result))
  }
}

if (length(failures) == 0L) {
  cat("all spec vectors passed\n")
  quit(status = 0)
}
for (failure in failures) cat(failure, "\n", file = stderr())
quit(status = 1)
