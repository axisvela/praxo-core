import type { Middleware } from "../middleware";

export const RUN_CLEANUP = Symbol("praxo.runCleanup");

export interface RunScopedMiddleware {
  [RUN_CLEANUP]?: (runId: string) => void;
}

export function withRunCleanup(
  middleware: Middleware,
  cleanup: (runId: string) => void
): Middleware {
  (middleware as RunScopedMiddleware)[RUN_CLEANUP] = cleanup;
  return middleware;
}

export function cleanupRunScoped(
  middleware: readonly Middleware[],
  runId: string
): void {
  for (const item of middleware) {
    const cleanup = (item as RunScopedMiddleware)[RUN_CLEANUP];
    if (typeof cleanup === "function") {
      cleanup(runId);
    }
  }
}
