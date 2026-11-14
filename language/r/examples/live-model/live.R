if (requireNamespace("praxocore", quietly = TRUE)) {
  library(praxocore)
}

env_or <- function(name, fallback) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else fallback
}

base_url <- env_or("PRAXO_BASE_URL", "http://localhost:11434/v1")
model_name <- env_or("PRAXO_MODEL", "qwen3.5:4b")
prompt <- env_or(
  "PRAXO_PROMPT",
  "What time is it? Use the get_time tool and reply with the time."
)

adapter <- openai_compatible(
  base_url,
  model_name,
  api_key = env_or("PRAXO_API_KEY", "")
)

get_time <- list(
  name = "get_time",
  description = "Return the current UTC time in ISO 8601 format.",
  parameters = list(type = "object", properties = list()),
  invoke = function(arguments) {
    format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
)

policy <- function(action) {
  if (identical(action$kind, "model.generate")) {
    return(list(allowed = TRUE))
  }
  if (identical(action$kind, "tool.invoke")) {
    return(list(
      allowed = identical(action$toolName, "get_time"),
      reason = "only get_time is permitted"
    ))
  }
  list(allowed = FALSE, reason = "unsupported action")
}

result <- tryCatch(
  agent_run(
    openai_compatible_model(adapter),
    prompt,
    tools = list(get_time),
    allowed_tools = "get_time",
    policy = policy,
    max_steps = 4L
  ),
  error = function(error) {
    stop(
      paste0(
        "live model run failed: ", conditionMessage(error),
        "\n\nCheck PRAXO_BASE_URL (", base_url, "), PRAXO_MODEL (",
        model_name, "), and PRAXO_API_KEY"
      ),
      call. = FALSE
    )
  }
)

cat(result$output, "\n", sep = "")
