plugin_check_keys <- function(value, allowed, where) {
  unknown <- setdiff(names(value), allowed)
  if (length(unknown) > 0L) stop("plugin: manifest: unknown field ", unknown[1], " in ", where)
}

plugin_as_object <- function(value, where) {
  if (is.null(value)) return(structure(list(), names = character(0)))
  if (!is.list(value) || is.null(names(value))) stop("plugin: manifest: ", where, " must be an object")
  value
}

plugin_as_string <- function(value, where) {
  if (!is.character(value) || length(value) != 1L) stop("plugin: manifest: ", where, " must be a string")
  value
}

plugin_as_int <- function(value, where) {
  if (!is.numeric(value) || length(value) != 1L) stop("plugin: manifest: ", where, " must be an integer")
  as.integer(value)
}

plugin_text <- function(value) {
  is.character(value) && length(value) == 1L && nzchar(value)
}

plugin_parse_manifest <- function(raw) {
  if (!nzchar(trimws(raw))) stop("plugin: manifest is empty")
  root <- tryCatch(json_parse(raw), error = function(e) stop("plugin: manifest: ", conditionMessage(e)))
  if (!is.list(root) || is.null(names(root))) stop("plugin: manifest must be an object")
  plugin_check_keys(root, c("schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
                            "capabilities", "permissions", "limits", "isolation", "health",
                            "signature", "sbom"), "manifest")
  schema_version <- plugin_as_int(json_get(root, "schemaVersion"), "schemaVersion")
  if (schema_version != 1L) stop("plugin: manifest: schemaVersion = ", schema_version, ", want 1")
  id <- plugin_as_string(json_get(root, "id"), "id")
  if (!grepl("^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", id, perl = TRUE)) {
    stop("plugin: manifest: id ", id, " is not reverse-DNS")
  }
  version <- plugin_as_string(json_get(root, "version"), "version")
  if (!grepl("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?$", version, perl = TRUE)) {
    stop("plugin: manifest: version ", version, " is not semver")
  }
  kind <- plugin_as_string(json_get(root, "kind"), "kind")
  kinds <- c("tool.provider.v1", "model.provider.v1", "policy.provider.v1",
             "memory.provider.v1", "sandbox.provider.v1")
  if (!(kind %in% kinds)) stop("plugin: manifest: kind ", kind, " is not a known contract")
  protocol <- plugin_as_string(json_get(root, "protocol"), "protocol")
  if (protocol != "jsonrpc-2") stop("plugin: manifest: protocol = ", protocol, ", want jsonrpc-2")
  entrypoint <- plugin_as_object(json_get(root, "entrypoint"), "entrypoint")
  plugin_check_keys(entrypoint, c("type", "command", "module", "image", "args", "dir"), "entrypoint")
  entry_type <- plugin_as_string(json_get(entrypoint, "type"), "entrypoint.type")
  required <- switch(entry_type, process = "command", wasm = "module", container = "image",
                     stop("plugin: manifest: unknown entrypoint type ", entry_type))
  if (!plugin_text(json_get(entrypoint, required))) {
    stop("plugin: manifest: ", entry_type, " entrypoint requires ", required)
  }
  isolation <- plugin_as_string(json_get(root, "isolation"), "isolation")
  if (isolation != entry_type) stop("plugin: manifest: isolation ", isolation, " does not match entrypoint ", entry_type)
  permissions <- plugin_as_object(json_get(root, "permissions"), "permissions")
  plugin_check_keys(permissions, c("filesystem", "network", "env"), "permissions")
  limits <- plugin_as_object(json_get(root, "limits"), "limits")
  plugin_check_keys(limits, c("memoryMB", "cpuMillis", "timeoutMs", "maxInflight"), "limits")
  for (key in names(limits)) {
    if (plugin_as_int(limits[[key]], paste0("limits.", key)) < 0L) stop("plugin: manifest: limits must not be negative")
  }
  health <- plugin_as_object(json_get(root, "health"), "health")
  plugin_check_keys(health, c("method", "intervalMs"), "health")
  signature <- json_get(root, "signature", NULL)
  if (!is.null(signature) && !is_json_null(signature)) {
    signature <- plugin_as_object(signature, "signature")
    plugin_check_keys(signature, c("algorithm", "keyId"), "signature")
    if (!plugin_text(json_get(signature, "algorithm")) || !plugin_text(json_get(signature, "keyId"))) {
      stop("plugin: manifest: signature requires algorithm and keyId")
    }
  }
  capabilities <- character()
  raw_capabilities <- json_get(root, "capabilities", NULL)
  if (!is.null(raw_capabilities) && !is_json_null(raw_capabilities)) {
    if (!is.list(raw_capabilities) || !is.null(names(raw_capabilities))) {
      stop("plugin: manifest: capabilities must be an array")
    }
    for (item in raw_capabilities) capabilities <- c(capabilities, plugin_as_string(item, "capabilities"))
  }
  if ("" %in% capabilities) stop("plugin: manifest: capability must not be empty")
  if (length(capabilities) != length(unique(capabilities))) stop("plugin: manifest: duplicate capability")
  list(schemaVersion = schema_version, id = id, version = version, kind = kind,
       entrypoint = entrypoint, protocol = protocol, capabilities = capabilities,
       permissions = permissions, limits = limits, isolation = isolation, health = health)
}
