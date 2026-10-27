args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grep("^--file=", args)]
script <- sub("^--file=", "", script_arg[1])
root <- normalizePath(file.path(dirname(script), "..", "..", ".."))
source(file.path(root, "language", "r", "R", "json.R"))
source(file.path(root, "language", "r", "R", "toolcall.R"))
source(file.path(root, "language", "r", "R", "jsonschema.R"))
source(file.path(root, "language", "r", "R", "plugin.R"))

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
cat("R wire tests passed\n")
