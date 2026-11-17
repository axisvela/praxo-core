args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grep("^--file=", args)]
script <- if (length(script_arg)) sub("^--file=", "", script_arg[1]) else ""
test_dir <- if (nzchar(script)) dirname(normalizePath(script)) else getwd()
root <- normalizePath(file.path(test_dir, "..", "..", "..", ".."))
source(file.path(root, "language", "r", "R", "json.R"))
source(file.path(root, "language", "r", "R", "core.R"))

expect_error <- function(expr, pattern) {
  error <- tryCatch({ force(expr); NULL }, error = function(value) value)
  stopifnot(inherits(error, "praxo_error"))
  stopifnot(grepl(pattern, error$code, fixed = TRUE))
  invisible(error)
}

new_budget <- function(remaining) {
  budget <- new.env(parent = emptyenv())
  budget$remaining <- as.integer(remaining)
  budget$available <- function() budget$remaining > 0L
  budget$take <- function() {
    if (budget$remaining <= 0L) return(FALSE)
    budget$remaining <- budget$remaining - 1L
    TRUE
  }
  budget
}

new_authority <- function(allowed, delegable, max_depth, max_children,
                          depth = 0L, budget = new_budget(1L), policy = NULL) {
  list(
    allowed = as.character(allowed),
    delegable = as.character(delegable),
    maxDepth = as.integer(max_depth),
    maxChildren = as.integer(max_children),
    depth = as.integer(depth),
    budget = budget,
    policy = policy
  )
}

compose_policy <- function(parent, child) {
  function(action) {
    if (!is.null(parent)) {
      decision <- parent(action)
      if (!isTRUE(decision$allowed)) return(decision)
    }
    if (!is.null(child)) return(child(action))
    list(allowed = TRUE, reason = "delegation policy chain allowed")
  }
}

new_governor <- function(authority) {
  governor <- new.env(parent = emptyenv())
  governor$authority <- authority
  governor$active <- 0L
  governor$delegate <- function(allowed, delegable = character(), policy = NULL) {
    allowed <- as.character(allowed)
    delegable <- as.character(delegable)
    if (authority$depth + 1L > authority$maxDepth) {
      praxo_error("DELEGATION_DEPTH", "delegation depth exceeded")
    }
    if (length(allowed) == 0L) {
      praxo_error("DELEGATION_SCOPE", "delegation tool scope is empty")
    }
    if (!all(allowed %in% authority$delegable) ||
        !all(allowed %in% authority$allowed)) {
      praxo_error("DELEGATION_SCOPE", "delegation scope exceeds parent")
    }
    if (!all(delegable %in% authority$delegable)) {
      praxo_error("DELEGATION_SCOPE", "child delegable scope exceeds parent")
    }
    if (!authority$budget$available()) {
      praxo_error("DELEGATION_BUDGET", "delegation budget exhausted")
    }
    if (governor$active >= authority$maxChildren) {
      praxo_error("DELEGATION_CHILDREN", "delegation child limit exceeded")
    }
    governor$active <- governor$active + 1L
    released <- new.env(parent = emptyenv())
    released$done <- FALSE
    release <- function() {
      if (isTRUE(released$done)) return(invisible(NULL))
      released$done <- TRUE
      governor$active <- governor$active - 1L
      invisible(NULL)
    }
    child_authority <- new_authority(
      allowed,
      delegable,
      authority$maxDepth,
      authority$maxChildren,
      authority$depth + 1L,
      authority$budget,
      compose_policy(authority$policy, policy)
    )
    child_scope(child_authority, release)
  }
  governor
}

budgeted_tool <- function(inner, budget) {
  list(
    name = inner$name,
    description = inner$description,
    parameters = inner$parameters,
    invoke = function(arguments) {
      if (!budget$take()) {
        praxo_error("DELEGATION_BUDGET", "delegation budget exhausted")
      }
      inner$invoke(arguments)
    }
  )
}

child_scope <- function(authority, release) {
  list(
    authority = authority,
    release = release,
    run = function(model, tools, prompt, cancellation = NULL,
                   middleware = list()) {
      scoped <- list()
      for (tool in tools) {
        if (tool$name %in% authority$allowed) {
          scoped[[length(scoped) + 1L]] <- budgeted_tool(tool, authority$budget)
        }
      }
      agent_run(
        model,
        prompt,
        tools = scoped,
        policy = authority$policy,
        middleware = middleware,
        allowed_tools = authority$allowed,
        cancellation = cancellation,
        max_steps = 3L,
        require_policy = TRUE,
        require_tool_scope = TRUE
      )
    }
  )
}

fixture_model <- function(tool_name, target, completion) {
  calls <- new.env(parent = emptyenv())
  calls$count <- 0L
  list(
    calls = function() calls$count,
    generate = function(request) {
      calls$count <- calls$count + 1L
      last <- request$messages[[length(request$messages)]]
      if (identical(last$role, roles$tool)) {
        return(response(message(roles$assistant, completion)))
      }
      response(message(
        roles$assistant,
        "",
        tool_calls = list(tool_call(
          "call-1", tool_name, list(target = target)
        ))
      ))
    }
  )
}

record_tool <- function() {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  list(
    tool = list(
      name = "record",
      description = "Record a delegated effect",
      parameters = list(
        type = "object",
        required = list("target"),
        properties = list(target = list(type = "string"))
      ),
      invoke = function(arguments) {
        state$calls <- state$calls + 1L
        "recorded"
      }
    ),
    calls = function() state$calls
  )
}

allow_all <- function(action) list(allowed = TRUE, reason = "root")

record_policy <- function(action) {
  if (!identical(action$kind, "tool.invoke")) {
    return(list(allowed = TRUE, reason = "non-tool action"))
  }
  if (!identical(action$toolName, "record")) {
    return(list(allowed = FALSE, reason = "child may only record"))
  }
  target <- action$arguments$target %||% ""
  if (identical(target, "blocked")) {
    return(list(allowed = FALSE, reason = "blocked target"))
  }
  list(allowed = TRUE, reason = "record allowed")
}

record <- record_tool()
tools <- list(record$tool)

root_governor <- new_governor(new_authority(
  c("record", "parent_only"),
  "record",
  1L,
  2L,
  budget = new_budget(2L),
  policy = allow_all
))

expect_error(
  root_governor$delegate("parent_only"),
  "DELEGATION_SCOPE"
)
stopifnot(identical(record$calls(), 0L))

root_governor$delegate("record", policy = record_policy)$release()

depth_root <- new_governor(new_authority(
  "record", "record", 1L, 1L, budget = new_budget(2L), policy = allow_all
))
depth_child <- depth_root$delegate("record", policy = record_policy)
depth_child$authority$delegable <- "record"
expect_error(
  new_governor(depth_child$authority)$delegate("record"),
  "DELEGATION_DEPTH"
)
depth_child$release()

child_limit <- new_governor(new_authority(
  "record", "record", 1L, 1L, budget = new_budget(2L), policy = allow_all
))
first_child <- child_limit$delegate("record", policy = record_policy)
expect_error(child_limit$delegate("record"), "DELEGATION_CHILDREN")
first_child$release()
child_limit$delegate("record")$release()

budget_record <- record_tool()
budget_tools <- list(budget_record$tool)
budget_root <- new_governor(new_authority(
  "record", "record", 1L, 2L, budget = new_budget(1L), policy = allow_all
))
first <- budget_root$delegate("record", policy = record_policy)
second <- budget_root$delegate("record", policy = record_policy)
first_model <- fixture_model("record", "first", "first-done")
invisible(first$run(first_model$generate, budget_tools, "record once"))
expect_error(
  second$run(
    fixture_model("record", "second", "second-done")$generate,
    budget_tools,
    "record twice"
  ),
  "DELEGATION_BUDGET"
)
stopifnot(identical(budget_record$calls(), 1L))
first$release()
second$release()

cancel_record <- record_tool()
cancel_tools <- list(cancel_record$tool)
cancel_root <- new_governor(new_authority(
  "record", "record", 1L, 1L, budget = new_budget(1L), policy = allow_all
))
canceled <- cancel_root$delegate("record", policy = record_policy)
expect_error(
  canceled$run(
    fixture_model("record", "safe", "unexpected")$generate,
    cancel_tools,
    "record after cancel",
    cancellation = function() TRUE
  ),
  "AGENT_CANCELLED"
)
stopifnot(identical(cancel_record$calls(), 0L))
canceled$release()

edit_record <- record_tool()
edit_tools <- list(edit_record$tool)
edit_root <- new_governor(new_authority(
  "record", "record", 1L, 1L, budget = new_budget(1L), policy = allow_all
))
edited <- edit_root$delegate("record", policy = record_policy)
edit <- list(before_tool = function(call) {
  call$arguments$target <- "blocked"
  call
})
expect_error(
  edited$run(
    fixture_model("record", "safe", "unexpected")$generate,
    edit_tools,
    "record safely",
    middleware = list(edit)
  ),
  "AGENT_POLICY_DENIED"
)
stopifnot(identical(edit_record$calls(), 0L))
edited$release()

cat("R governance: delegation checks passed (6)\n")
