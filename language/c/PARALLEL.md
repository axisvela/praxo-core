# C Parallel Tool Design

## Goal

Run up to `max_parallel_tools` tool calls concurrently without changing
authorization, middleware, event, or message ordering.

## Constraints

- `PxArena` is not thread-safe and owns every parsed JSON value.
- Tool callbacks receive `PxArena *` and may return values allocated in it.
- Policy and middleware callbacks are ordered and stateful; they cannot run in
  worker threads.
- Windows builds may not provide POSIX threads; CI runs the threaded path on
  Linux.

## Design

1. Prepare every tool call on the calling thread:
   - check the allowlist and authorize the original call;
   - run `before_tool` middleware in order;
   - re-check the final name, reauthorize changed name/arguments;
   - emit `tool.call` in the original order;
   - serialize the final arguments to JSON.
2. Execute prepared jobs in bounded batches:
   - Unix builds use `pthread_create` with one worker per batch slot;
   - each worker creates its own `PxArena`, parses the argument JSON, invokes the
     tool callback, serializes the result to a `malloc` string, and frees its
     arena;
   - Windows builds use the sequential path.
3. Finish on the calling thread:
   - parse each result string back into the run arena;
   - append tool messages in original call order;
   - free worker-owned result strings.

The JSON boundary between threads is deliberate: it keeps `PxArena` single-owner
and makes the worker result independent of worker lifetime.

## Alternatives Considered

- Shared arena across threads: rejected because `PxArena` has no locking.
- Fork per tool: rejected because tool callbacks and caller state are not
  portable across process boundaries, and Windows behavior differs.
- Parallel policy/middleware: rejected because hooks are ordered and may mutate
  shared state.

## Limits

- `max_parallel_tools <= 1` or one call uses the sequential path.
- Windows uses the sequential path; platform CI must state that limit.
- Tool callbacks must be safe to run concurrently when parallel execution is
  enabled.
- Cancellation is checked before preparation and before each sequential job;
  a cancellation during an already-running parallel batch does not preempt
  workers.
- Result order is preserved even when tool completion order differs.
