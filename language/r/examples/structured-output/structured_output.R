source("language/r/R/json.R")
source("language/r/R/jsonschema.R")
source("language/r/R/core.R")

schema <- json_parse(
  '{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}'
)
errors <- schema_validate(schema, json_parse('{"name":"ok"}'))
stopifnot(length(errors) == 0L)

errors <- schema_validate(schema, json_parse("{}"))
stopifnot(length(errors) > 0L)

cat("R structured output example passed\n")
