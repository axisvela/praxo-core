args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grep("^--file=", args)]
script <- sub("^--file=", "", script_arg[1])
script_dir <- dirname(script)
root <- normalizePath(file.path(script_dir, "..", ".."))

version <- sub("^Version:\\s*", "",
               grep("^Version:", readLines(file.path(script_dir, "DESCRIPTION")), value = TRUE)[1])
spec <- trimws(readLines(file.path(root, "spec", "SPEC_VERSION"), warn = FALSE)[1])

files <- sort(list.files(file.path(script_dir, "R"), pattern = "\\.R$", full.names = TRUE))
symbols <- character()
for (file in files) {
  lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  matches <- regmatches(
    lines,
    regexec("^([A-Za-z_.][A-Za-z0-9_.]*)\\s*<-", lines)
  )
  for (match in matches) {
    if (length(match) == 2L) symbols <- c(symbols, match[2L])
  }
}
symbols <- sort(unique(symbols))

content <- paste(
  c(
    paste0("# PRAXO-CORE R API ", version),
    paste0("# SPEC_VERSION ", spec),
    "",
    symbols,
    ""
  ),
  collapse = "\n"
)

check <- "--check" %in% commandArgs(trailingOnly = TRUE)
target <- file.path(script_dir, "api", paste0(version, ".txt"))

if (check) {
  if (!file.exists(target)) {
    cat("missing snapshot: ", target, "\n", file = stderr())
    quit(status = 1)
  }
  if (!identical(readChar(target, file.info(target)$size, useBytes = TRUE), content)) {
    cat("snapshot is stale: ", target, "\n", file = stderr())
    quit(status = 1)
  }
  cat("snapshot is current: ", target, "\n")
} else {
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  writeChar(content, target, eos = NULL)
  cat("wrote ", target, "\n")
}
