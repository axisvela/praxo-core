source("language/r/R/json.R")
source("language/r/R/core.R")

all_types <- character()
tool_types <- character()
all_sink <- list(emit = function(event) all_types <<- c(all_types, event$type))
tool_sink <- list(emit = function(event) tool_types <<- c(tool_types, event$type))
filtered <- filter_sink(tool_sink, function(event) identical(event$type, "tool.call"))
multi <- multi_sink(list(all_sink, filtered))

for (kind in c("run.started", "tool.call", "run.completed")) {
  sink_emit(multi, list(type = kind, sessionId = "s1"))
}

stopifnot(identical(all_types, c("run.started", "tool.call", "run.completed")))
stopifnot(identical(tool_types, "tool.call"))

cat("R event sink example passed\n")
