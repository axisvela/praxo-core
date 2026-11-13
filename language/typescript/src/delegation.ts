export type SubagentMode = "isolated" | "fork";

export type SubagentStatus =
  | "queued"
  | "running"
  | "completed"
  | "failed"
  | "canceled";

export interface SubagentRequest {
  parentSessionId: string;
  agentId: string;
  prompt: string;
  context?: Record<string, unknown>;
  mode?: SubagentMode;
  history?: unknown[];
}

export interface SubagentResult {
  taskId?: string;
  agentId?: string;
  output: string;
  usage?: unknown;
}

export interface SubagentRunner {
  run(request: SubagentRequest): Promise<SubagentResult>;
}

export interface ControllableRunner extends SubagentRunner {
  update(taskId: string, prompt: string): Promise<void>;
}

export interface SubagentTask {
  id: string;
  parentSessionId: string;
  agentId: string;
  mode: SubagentMode;
  status: SubagentStatus;
  output: string;
  error: string;
  createdAt: string;
  updatedAt: string;
}

export class SubagentUpdateUnsupported extends Error {
  constructor() {
    super("agent: subagent update unsupported");
  }
}

interface TaskState {
  task: SubagentTask;
  resolve: () => void;
}

function terminal(status: SubagentStatus): boolean {
  return status === "completed" || status === "failed" || status === "canceled";
}

export class SubagentManager {
  private readonly state = new Map<string, TaskState>();
  private sequence = 0;

  constructor(private readonly runner: SubagentRunner) {}

  async launch(request: SubagentRequest): Promise<SubagentTask> {
    if (!this.runner) throw new Error("agent: subagent runner is required");
    if (!request.parentSessionId || !request.agentId) {
      throw new Error(
        "agent: subagent parent session and agent id are required"
      );
    }
    const id = `subagent-${++this.sequence}`;
    const now = new Date().toISOString();
    let resolve: () => void = () => undefined;
    const done = new Promise<void>((settle) => {
      resolve = settle;
    });
    const task: SubagentTask = {
      id,
      parentSessionId: request.parentSessionId,
      agentId: request.agentId,
      mode: request.mode ?? "isolated",
      status: "queued",
      output: "",
      error: "",
      createdAt: now,
      updatedAt: now,
    };
    this.state.set(id, { task, resolve });
    void this.execute(id, request, done);
    return { ...task };
  }

  check(taskId: string): SubagentTask | undefined {
    const state = this.state.get(taskId);
    return state ? { ...state.task } : undefined;
  }

  async wait(taskId: string, timeoutMs?: number): Promise<SubagentTask> {
    const state = this.state.get(taskId);
    if (!state) {
      throw new Error(`agent: unknown subagent task "${taskId}"`);
    }
    if (!terminal(state.task.status)) {
      const done = new Promise<void>((resolve) => {
        const current = state.resolve;
        state.resolve = () => {
          current();
          resolve();
        };
      });
      if (timeoutMs === undefined) {
        await done;
      } else {
        await withTimeout(done, timeoutMs);
      }
    }
    return { ...state.task };
  }

  async update(taskId: string, prompt: string): Promise<void> {
    if (!isControllable(this.runner)) {
      throw new SubagentUpdateUnsupported();
    }
    const state = this.state.get(taskId);
    if (!state) {
      throw new Error(`agent: unknown subagent task "${taskId}"`);
    }
    if (state.task.status !== "running") {
      throw new Error(`agent: subagent task "${taskId}" is not running`);
    }
    await this.runner.update(taskId, prompt);
  }

  async cancel(taskId: string): Promise<void> {
    const state = this.state.get(taskId);
    if (!state) {
      throw new Error(`agent: unknown subagent task "${taskId}"`);
    }
    if (terminal(state.task.status)) return;
    this.set(taskId, "canceled");
  }

  private async execute(
    taskId: string,
    request: SubagentRequest,
    done: Promise<void>
  ): Promise<void> {
    this.set(taskId, "running");
    try {
      const result = await this.runner.run(request);
      if (!terminal(this.state.get(taskId)!.task.status)) {
        this.set(taskId, "completed", result.output);
      }
    } catch (error) {
      if (!terminal(this.state.get(taskId)!.task.status)) {
        this.set(taskId, "failed", "", String(error));
      }
    }
    await done;
  }

  private set(
    taskId: string,
    status: SubagentStatus,
    output = "",
    error = ""
  ): void {
    const state = this.state.get(taskId);
    if (!state) return;
    state.task.status = status;
    state.task.output = output;
    state.task.error = error;
    state.task.updatedAt = new Date().toISOString();
    if (terminal(status)) {
      state.resolve();
    }
  }
}

function isControllable(runner: SubagentRunner): runner is ControllableRunner {
  return typeof (runner as ControllableRunner).update === "function";
}

async function withTimeout(
  promise: Promise<void>,
  timeoutMs: number
): Promise<void> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<void>((_, reject) => {
    timer = setTimeout(
      () => reject(new Error("agent: subagent wait timed out")),
      timeoutMs
    );
  });
  try {
    await Promise.race([promise, timeout]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}
