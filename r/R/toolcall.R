toolcall_parse_input <- function(raw) {
  value <- tryCatch(json_parse(raw), error = function(e) NULL)
  if (is.list(value) && !is.null(names(value))) return(value)
  NULL
}

toolcall_parse <- function(content) {
  call <- toolcall_parse_json(content)
  if (is.null(call)) call <- toolcall_parse_xml(content)
  if (is.null(call)) call <- toolcall_parse_tag(content)
  if (is.null(call)) call <- toolcall_parse_plain(content)
  call
}

toolcall_parse_json <- function(content) {
  root <- tryCatch(json_parse(content), error = function(e) NULL)
  if (!is.list(root) || is.null(names(root))) return(NULL)
  name <- json_string(root, "name", "")
  if (is.null(name) || !nzchar(name)) return(NULL)
  input <- json_get(root, "input", list())
  if (!is.list(input) || is.null(names(input))) input <- list()
  list(
    name = name,
    input = input,
    operation = json_string(root, "operation", ""),
    resource = json_string(root, "resource", ""),
    risk = json_string(root, "risk", ""),
    reason = json_string(root, "reason", ""),
    idempotency_key = json_string(root, "idempotency_key", "")
  )
}

toolcall_parse_xml <- function(content) {
  pattern <- '(?s)<tool_call\\s+name="([^"]+)"\\s*>\\s*(.*?)\\s*</tool_call>'
  m <- regmatches(content, regexec(pattern, content, perl = TRUE))[[1]]
  if (length(m) < 3L) return(NULL)
  input <- toolcall_parse_input(m[3])
  if (is.null(input)) return(NULL)
  list(name = m[2], input = input, operation = "", resource = "", risk = "",
       reason = "", idempotency_key = "")
}

toolcall_parse_tag <- function(content) {
  pattern <- '(?s)<([A-Za-z][\\w-]*(?:\\.[\\w-]+)+)>\\s*(\\{.*?)\\s*(?:</[A-Za-z][\\w.-]*>|$)'
  m <- regmatches(content, regexec(pattern, content, perl = TRUE))[[1]]
  if (length(m) < 3L) return(NULL)
  input <- toolcall_parse_input(m[3])
  if (is.null(input)) return(NULL)
  list(name = m[2], input = input, operation = "", resource = "", risk = "",
       reason = "", idempotency_key = "")
}

toolcall_parse_plain <- function(content) {
  pattern <- '(?m)^\\s*([A-Za-z][\\w.-]*)\\s+(\\{.*\\})\\s*$'
  m <- regmatches(content, regexec(pattern, content, perl = TRUE))[[1]]
  if (length(m) < 3L || !grepl(".", m[2], fixed = TRUE)) return(NULL)
  input <- toolcall_parse_input(m[3])
  if (is.null(input)) return(NULL)
  list(name = m[2], input = input, operation = "", resource = "", risk = "",
       reason = "", idempotency_key = "")
}

toolcall_strip <- function(content) {
  patterns <- c(
    '(?s)<tool_call\\s+name="[^"]+"\\s*>.*?(?:</tool_call>|$)',
    '(?s)<tool_call_invoke>.*?(?:</tool_call_invoke>|$)',
    '(?s)<[A-Za-z][\\w-]*(?:\\.[\\w-]+)+>\\s*\\{.*?(?:</[A-Za-z][\\w.-]*>|$)'
  )
  out <- content
  for (pattern in patterns) out <- gsub(pattern, "", out, perl = TRUE)
  out <- gsub("\\n{3,}", "\n\n", out, perl = TRUE)
  trimws(out)
}
