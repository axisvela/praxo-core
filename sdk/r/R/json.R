json_null <- structure(list(), class = "praxo_json_null")

is_json_null <- function(value) inherits(value, "praxo_json_null")

json_parse <- function(text) {
  chars <- strsplit(text, "", fixed = TRUE)[[1]]
  n <- length(chars)
  i <- 1L

  skip <- function() {
    while (i <= n && chars[i] %in% c(" ", "\t", "\n", "\r")) i <<- i + 1L
  }

  parse_string <- function() {
    i <<- i + 1L
    out <- character()
    while (i <= n && chars[i] != "\"") {
      ch <- chars[i]
      if (ch == "\\") {
        i <<- i + 1L
        esc <- chars[i]
        if (esc == "u") {
          hex <- paste(chars[(i + 1L):(i + 4L)], collapse = "")
          out <- c(out, intToUtf8(strtoi(hex, 16L)))
          i <<- i + 4L
        } else {
          out <- c(out, switch(esc, "n" = "\n", "t" = "\t", "r" = "\r",
                               "b" = "\b", "f" = "\f", "\"" = "\"", "\\" = "\\", "/" = "/", esc))
        }
      } else {
        out <- c(out, ch)
      }
      i <<- i + 1L
    }
    i <<- i + 1L
    paste(out, collapse = "")
  }

  parse_number <- function() {
    start <- i
    while (i <= n && grepl("[0-9eE+.-]", chars[i])) i <<- i + 1L
    suppressWarnings(as.numeric(paste(chars[start:(i - 1L)], collapse = "")))
  }

  parse_value <- function() {
    skip()
    if (i > n) stop("unexpected end of JSON")
    ch <- chars[i]
    if (ch == "{") {
      i <<- i + 1L
      out <- list()
      skip()
      if (chars[i] == "}") { i <<- i + 1L; names(out) <- character(0); return(out) }
      repeat {
        skip()
        key <- parse_string()
        skip()
        if (chars[i] != ":") stop("expected ':'")
        i <<- i + 1L
        out[[key]] <- parse_value()
        skip()
        if (chars[i] == "}") { i <<- i + 1L; break }
        if (chars[i] != ",") stop("expected ','")
        i <<- i + 1L
      }
      return(out)
    }
    if (ch == "[") {
      i <<- i + 1L
      out <- list()
      skip()
      if (chars[i] == "]") { i <<- i + 1L; return(out) }
      repeat {
        out[[length(out) + 1L]] <- parse_value()
        skip()
        if (chars[i] == "]") { i <<- i + 1L; break }
        if (chars[i] != ",") stop("expected ','")
        i <<- i + 1L
      }
      return(out)
    }
    if (ch == "\"") return(parse_string())
    if (ch == "t") { i <<- i + 4L; return(TRUE) }
    if (ch == "f") { i <<- i + 5L; return(FALSE) }
    if (ch == "n") { i <<- i + 4L; return(json_null) }
    parse_number()
  }

  value <- parse_value()
  skip()
  if (i <= n) stop("trailing JSON data")
  value
}

json_encode <- function(value) {
  if (is.null(value) || is_json_null(value)) return("null")
  if (is.logical(value)) return(if (value) "true" else "false")
  if (is.numeric(value)) return(format(value, scientific = FALSE, trim = TRUE))
  if (is.character(value) && length(value) == 1L) {
    escaped <- gsub("\\\\", "\\\\\\\\", value)
    escaped <- gsub("\"", "\\\\\"", escaped)
    escaped <- gsub("\n", "\\\\n", escaped)
    return(paste0("\"", escaped, "\""))
  }
  if (is.list(value)) {
    if (!is.null(names(value))) {
      parts <- vapply(names(value), function(key) {
        paste0(json_encode(key), ":", json_encode(value[[key]]))
      }, character(1))
      return(paste0("{", paste(parts, collapse = ","), "}"))
    }
    parts <- vapply(value, json_encode, character(1))
    return(paste0("[", paste(parts, collapse = ","), "]"))
  }
  stop("cannot encode value")
}

json_get <- function(node, key, default = NULL) {
  if (is.list(node) && !is.null(names(node)) && key %in% names(node)) return(node[[key]])
  default
}

json_string <- function(node, key, default = NULL) {
  value <- json_get(node, key, default)
  if (is.character(value) && length(value) == 1L) return(value)
  default
}

json_bool <- function(node, key, default = FALSE) {
  value <- json_get(node, key, default)
  if (is.logical(value) && length(value) == 1L) return(value)
  default
}

json_int <- function(node, key, default = 0L) {
  value <- json_get(node, key, default)
  if (is.numeric(value) && length(value) == 1L) return(as.integer(value))
  as.integer(default)
}

json_array <- function(node, key) {
  value <- json_get(node, key, list())
  if (is.list(value) && is.null(names(value))) return(value)
  list()
}

json_equals <- function(left, right) {
  if (is_json_null(left) || is_json_null(right)) {
    return((is.null(left) || is_json_null(left)) && (is.null(right) || is_json_null(right)))
  }
  if (is.list(left) && is.list(right)) {
    if (!identical(names(left), names(right))) return(FALSE)
    if (length(left) != length(right)) return(FALSE)
    for (key in names(left)) if (!json_equals(left[[key]], right[[key]])) return(FALSE)
    return(TRUE)
  }
  if (is.numeric(left) && is.numeric(right)) return(isTRUE(all.equal(as.numeric(left), as.numeric(right))))
  identical(left, right)
}
