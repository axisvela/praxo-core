schema_validate <- function(schema, data) {
  errors <- list()
  errors <- schema_visit(schema, data, "$", errors)
  errors
}

schema_add <- function(errors, path, message) {
  errors[[length(errors) + 1L]] <- list(path = path, message = message)
  errors
}

schema_visit <- function(schema, data, path, errors) {
  kind <- if (is.list(schema)) json_string(schema, "type", "") else ""
  if (is.null(data) || is_json_null(data)) {
    if (nzchar(kind)) errors <- schema_add(errors, path, paste0("expected ", kind, ", got null"))
    return(errors)
  }
  if (kind == "object") return(schema_object(schema, data, path, errors))
  if (kind == "array") return(schema_array(schema, data, path, errors))
  if (kind == "string") return(schema_string(schema, data, path, errors))
  if (kind == "number" || kind == "integer") return(schema_number(schema, kind, data, path, errors))
  if (kind == "boolean") return(schema_boolean(schema, data, path, errors))
  errors
}

schema_object <- function(schema, data, path, errors) {
  if (!is.list(data) || is.null(names(data))) {
    return(schema_add(errors, path, "expected object"))
  }
  for (name in json_array(schema, "required")) {
    if (is.character(name) && !(name %in% names(data))) {
      errors <- schema_add(errors, paste0(path, ".", name), "required field missing")
    }
  }
  properties <- json_get(schema, "properties", list())
  if (is.list(properties) && !is.null(names(properties))) {
    for (name in names(properties)) {
      if (name %in% names(data) && is.list(properties[[name]])) {
        errors <- schema_visit(properties[[name]], data[[name]], paste0(path, ".", name), errors)
      }
    }
  }
  errors
}

schema_array <- function(schema, data, path, errors) {
  if (!is.list(data) || !is.null(names(data))) {
    return(schema_add(errors, path, "expected array"))
  }
  items <- json_get(schema, "items", list())
  if (is.list(items) && !is.null(names(items))) {
    for (index in seq_along(data)) {
      errors <- schema_visit(items, data[[index]], paste0(path, "[", index - 1L, "]"), errors)
    }
  }
  errors
}

schema_string <- function(schema, data, path, errors) {
  if (!is.character(data) || length(data) != 1L) {
    return(schema_add(errors, path, "expected string"))
  }
  count <- nchar(data, type = "chars")
  min <- json_int(schema, "minLength", 0L)
  max <- json_int(schema, "maxLength", 0L)
  if (min > 0L && count < min) errors <- schema_add(errors, path, paste0("min length ", min, ", got ", count))
  if (max > 0L && count > max) errors <- schema_add(errors, path, paste0("max length ", max, ", got ", count))
  pattern <- json_string(schema, "pattern", NULL)
  if (!is.null(pattern)) {
    ok <- tryCatch(grepl(pattern, data, perl = TRUE), error = function(e) FALSE)
    if (!isTRUE(ok)) errors <- schema_add(errors, path, paste0("pattern '", pattern, "' not matched"))
  }
  schema_enum(schema, data, path, errors)
}

schema_number <- function(schema, kind, data, path, errors) {
  if (!is.numeric(data) || length(data) != 1L) {
    return(schema_add(errors, path, "expected number"))
  }
  if (kind == "integer" && data != floor(data)) {
    return(schema_add(errors, path, paste0("expected integer, got ", data)))
  }
  errors <- schema_enum(schema, data, path, errors)
  minimum <- json_get(schema, "minimum", NULL)
  maximum <- json_get(schema, "maximum", NULL)
  if (is.numeric(minimum) && minimum != 0 && data < minimum) {
    errors <- schema_add(errors, path, "value below minimum")
  }
  if (is.numeric(maximum) && maximum != 0 && data > maximum) {
    errors <- schema_add(errors, path, "value above maximum")
  }
  errors
}

schema_boolean <- function(schema, data, path, errors) {
  if (!is.logical(data) || length(data) != 1L) {
    return(schema_add(errors, path, "expected boolean"))
  }
  schema_enum(schema, data, path, errors)
}

schema_enum <- function(schema, data, path, errors) {
  values <- json_get(schema, "enum", NULL)
  if (!is.list(values) || length(values) == 0L) return(errors)
  for (value in values) if (json_equals(value, data)) return(errors)
  schema_add(errors, path, "value not in enum")
}
