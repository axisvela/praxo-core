import {
  ContextBudget,
  ContextCompactor,
  Offloader,
  estimateTokens,
  loadAgentsMd,
} from "./context";
import {
  AbortError,
  ContextBudgetError,
  MaxStepsError,
  MaxTokensError,
  PolicyDeniedError,
  ToolNotFoundError,
} from "./errors";
import { Event, Sink } from "./event";
import {
  Middleware,
  MiddlewareToolCall,
  ModelCall,
  ModelHandler,
  ModelMiddleware,
  PIIRedactor,
  RunState,
  StructuredOutput,
  ToolResult,
  ToolSelector,
  callLimitMiddleware,
  fallbackModel,
  maybeAwait,
  mergeMiddleware,
  piiMiddleware,
  toolSelectionMiddleware,
} from "./middleware";
import {
  Message,
  Model,
  Request,
  Response,
  ResponseFormat,
  ROLE_SYSTEM,
  ROLE_TOOL,
  ROLE_USER,
  StreamingModel,
  ToolCall,
  ToolSpec,
  Usage,
  usage,
} from "./model";
import { Action, Decision, Hook } from "./policy";
import { Registry } from "./tool";

export interface Session {
  id: string;
  tenantId?: string;
  workspaceId?: string;
  messages?: Message[];
}

export interface Result {
  runId: string;
  output: string;
  steps: number;
  usage: Usage;
}

export interface AgentOptions {
  model: Model;
  tools?: Registry;
  events?: Sink;
  policy?: Hook;
  systemPrompt?: string;
  memoryFiles?: string[];
  context?: ContextBudget;
  compactor?: ContextCompactor;
  offloader?: Offloader;
  offloadThresholdBytes?: number;
  middleware?: Middleware[];
  modelMiddleware?: ModelMiddleware[];
  structuredOutput?: StructuredOutput;
  allowedTools?: string[];
  toolSelector?: ToolSelector;
  piiRedactor?: PIIRedactor;
  modelCallLimit?: number;
  toolCallLimit?: number;
  fallbackModel?: Model;
  toolChoice?: string;
  responseFormat?: ResponseFormat;
  maxSteps?: number;
  maxTokens?: number;
  maxParallelTools?: number;
  onDelta?: (delta: string) => void;
  signal?: AbortSignal;
}

export class Agent {
  private readonly systemPrompt: string;
  private readonly middleware: Middleware[];
  private readonly modelMiddleware: ModelMiddleware[];

  constructor(readonly options: AgentOptions) {
    const memory = loadAgentsMd(options.memoryFiles ?? []);
    this.systemPrompt = memory
      ? `${options.systemPrompt ?? ""}\n\n${memory}`.trim()
      : options.systemPrompt ?? "";

    const middleware = [...(options.middleware ?? [])];
    if (options.structuredOutput) {
      middleware.push(options.structuredOutput.middleware());
    }
    if (options.toolSelector) {
      middleware.push(toolSelectionMiddleware(options.toolSelector));
    }
    if (options.piiRedactor) {
      middleware.push(piiMiddleware(options.piiRedactor));
    }
    if (
      (options.modelCallLimit ?? 0) > 0 ||
      (options.toolCallLimit ?? 0) > 0
    ) {
      middleware.push(
        callLimitMiddleware(
          options.modelCallLimit ?? 0,
          options.toolCallLimit ?? 0
        )
      );
    }
    this.middleware = mergeMiddleware(middleware);

    const modelMiddleware = [...(options.modelMiddleware ?? [])];
    if (options.fallbackModel) {
      modelMiddleware.push(fallbackModel(options.fallbackModel));
    }
    this.modelMiddleware = modelMiddleware;
  }

  async run(session: Session, prompt: string): Promise<Result> {
    const model = this.options.model;
    if (!model) throw new Error("agent: model is required");
    this.throwIfAborted();
    const maxSteps =
      (this.options.maxSteps ?? 8) > 0 ? this.options.maxSteps ?? 8 : 8;
    const runId = `run-${Date.now() * 1000 + Math.floor(Math.random() * 1000)}`;
    const messages: Message[] = [...(session.messages ?? [])];
    if (this.systemPrompt) {
      messages.unshift({
        role: ROLE_SYSTEM,
        content: this.systemPrompt,
      });
    }
    messages.push({ role: ROLE_USER, content: prompt });
    let total = usage();

    await this.beforeRun({ runId, session, prompt });
    await this.emit({ type: "run.started", sessionId: session.id, runId });
    let afterRunInvoked = false;
    try {
      for (let step = 1; step <= maxSteps; step += 1) {
        this.throwIfAborted();
        await this.authorize({
          kind: "model.generate",
          sessionId: session.id,
        });
        const compacted = await this.compact(messages);
        messages.length = 0;
        messages.push(...compacted);

        const request: Request = {
          messages,
          tools: this.toolSpecs(),
          toolChoice: this.options.toolChoice,
          responseFormat: this.options.responseFormat,
          signal: this.options.signal,
        };
        const modelCall: ModelCall = {
          runId,
          sessionId: session.id,
          request,
        };
        await this.beforeModel(modelCall);
        let response: Response;
        if (modelCall.skip) {
          if (!modelCall.response) {
            throw new Error(
              "agent: model middleware skipped without a response"
            );
          }
          response = modelCall.response;
        } else {
          response = await this.generate(modelCall.request);
        }
        await this.afterModel(modelCall, response);
        total = usage(
          total.inputTokens + (response.usage?.inputTokens ?? 0),
          total.outputTokens + (response.usage?.outputTokens ?? 0),
          (total.cachedTokens ?? 0) + (response.usage?.cachedTokens ?? 0)
        );
        if (
          (this.options.maxTokens ?? 0) > 0 &&
          total.inputTokens + total.outputTokens >
            (this.options.maxTokens ?? 0)
        ) {
          throw new MaxTokensError();
        }
        messages.push(response.message);
        if (!response.message.toolCalls?.length) {
          const result: Result = {
            runId,
            output: response.message.content ?? "",
            steps: step,
            usage: total,
          };
          afterRunInvoked = true;
          await this.afterRun(result, null);
          await this.emit({
            type: "run.completed",
            sessionId: session.id,
            runId,
          });
          return result;
        }
        for (const call of response.message.toolCalls) {
          messages.push(
            await this.invokeTool(call, runId, session.id)
          );
        }
      }
      throw new MaxStepsError();
    } catch (error) {
      if (!afterRunInvoked) {
        try {
          await this.afterRun(null, error);
        } catch {
          // preserve the original run error
        }
      }
      try {
        await this.emit({
          type: "run.failed",
          sessionId: session.id,
          runId,
          data: { error: error instanceof Error ? error.message : String(error) },
        });
      } catch {
        // event sinks must not mask the run error
      }
      throw error;
    }
  }

  private async compact(messages: Message[]): Promise<Message[]> {
    const budget = this.options.context;
    if (!budget || budget.maxTokens <= 0) return messages;
    let current = messages;
    if (
      this.options.compactor &&
      estimateTokens(current) > budget.maxTokens
    ) {
      current = await this.options.compactor.compact(current, budget);
    }
    const [out, ok] = budget.compact(current);
    if (!ok) throw new ContextBudgetError();
    return out;
  }

  private toolSpecs(): ToolSpec[] {
    const specs = this.options.tools?.specs() ?? [];
    const allowed = this.options.allowedTools ?? [];
    if (!allowed.length) return specs;
    const set = new Set(allowed);
    return specs.filter((spec) => set.has(spec.name));
  }

  private toolAllowed(name: string): boolean {
    const allowed = this.options.allowedTools ?? [];
    return !allowed.length || allowed.includes(name);
  }

  private async generate(request: Request): Promise<Response> {
    const model = this.options.model;
    const base: ModelHandler = async (req) => {
      if (this.options.onDelta) {
        const streaming = model as Partial<StreamingModel>;
        if (typeof streaming.generateStream === "function") {
          return streaming.generateStream(req, this.options.onDelta);
        }
      }
      return model.generate(req);
    };
    let handler = base;
    for (let index = this.modelMiddleware.length - 1; index >= 0; index -= 1) {
      handler = this.modelMiddleware[index](handler);
    }
    return handler(request);
  }

  private async invokeTool(
    call: ToolCall,
    runId: string,
    sessionId: string
  ): Promise<Message> {
    this.throwIfAborted();
    if (!this.toolAllowed(call.name)) {
      throw new Error(`agent: tool ${call.name} is not allowed`);
    }
    await this.authorize({
      kind: "tool.invoke",
      sessionId,
      toolName: call.name,
      arguments: call.arguments,
    });
    if (!this.options.tools) {
      throw new ToolNotFoundError(
        `tool ${call.name} is not registered`
      );
    }
    const tool = this.options.tools.get(call.name);
    const toolCall: MiddlewareToolCall = {
      runId,
      sessionId,
      call,
    };
    await this.beforeTool(toolCall);
    const active = toolCall.call;
    let value: unknown;
    let error: unknown;
    if (toolCall.skip) {
      value = toolCall.result;
      error = toolCall.error;
    } else {
      await this.emit({
        type: "tool.call",
        sessionId,
        runId,
        data: { name: active.name, arguments: active.arguments },
      });
      try {
        value = await tool.invoke(active.arguments);
      } catch (caught) {
        error = caught;
      }
    }
    const result: ToolResult = { value, error };
    await this.afterTool(toolCall, result);
    if (result.error !== undefined && result.error !== null) {
      throw result.error;
    }
    let content: string;
    try {
      const raw = Buffer.from(JSON.stringify(result.value) ?? "null", "utf8");
      content = raw.toString("utf8");
      const threshold = this.options.offloadThresholdBytes ?? 0;
      if (this.options.offloader && threshold > 0 && raw.length > threshold) {
        const ref = await this.options.offloader.offload(
          active.name,
          active.id,
          raw
        );
        if (!ref) {
          throw new Error(
            "agent: offloader returned an empty placeholder"
          );
        }
        content = ref;
      }
    } catch (caught) {
      if (caught instanceof Error && caught.message.includes("offloader")) {
        throw caught;
      }
      throw new Error(
        `agent: tool ${active.name} result is not JSON-serializable: ${String(caught)}`
      );
    }
    return { role: ROLE_TOOL, content, toolId: active.id };
  }

  private async beforeRun(state: RunState): Promise<void> {
    for (const middleware of this.middleware) {
      if (middleware.beforeRun) {
        await maybeAwait(middleware.beforeRun(state));
      }
    }
  }

  private async beforeModel(call: ModelCall): Promise<void> {
    for (const middleware of this.middleware) {
      if (middleware.beforeModel) {
        await maybeAwait(middleware.beforeModel(call));
      }
      if (call.skip) break;
    }
  }

  private async afterModel(
    call: ModelCall,
    response: Response
  ): Promise<void> {
    for (const middleware of this.middleware) {
      if (middleware.afterModel) {
        await maybeAwait(middleware.afterModel(call, response));
      }
    }
  }

  private async beforeTool(call: MiddlewareToolCall): Promise<void> {
    for (const middleware of this.middleware) {
      if (middleware.beforeTool) {
        await maybeAwait(middleware.beforeTool(call));
      }
      if (call.skip) break;
    }
  }

  private async afterTool(
    call: MiddlewareToolCall,
    result: ToolResult
  ): Promise<void> {
    for (const middleware of this.middleware) {
      if (middleware.afterTool) {
        await maybeAwait(middleware.afterTool(call, result));
      }
    }
  }

  private async afterRun(
    result: Result | null,
    error: unknown
  ): Promise<void> {
    for (const middleware of this.middleware) {
      if (middleware.afterRun) {
        await maybeAwait(middleware.afterRun(result, error));
      }
    }
  }

  private throwIfAborted(): void {
    if (this.options.signal?.aborted) {
      throw new AbortError();
    }
  }

  private async authorize(action: Action): Promise<void> {
    if (!this.options.policy) return;
    const decision = await maybeAwait(
      this.options.policy.authorize(action)
    );
    if (!decision.allowed) {
      throw new PolicyDeniedError(
        `agent: ${action.kind} denied: ${decision.reason ?? ""}`
      );
    }
  }

  private async emit(event: Event): Promise<void> {
    if (!this.options.events) return;
    await this.options.events.emit({
      ...event,
      at: event.at ?? new Date().toISOString(),
    });
  }
}

export type { Decision };
