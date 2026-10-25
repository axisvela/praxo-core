import {
  Agent,
  AgentOptions,
  Event,
  Message,
  Model,
  PraxoError,
  Registry,
  Request,
  Response,
  ROLE_ASSISTANT,
  Session,
  Sink,
  Tool,
  ToolCall,
  usage,
} from "../index";
import type { Vector } from "./run";

interface ScriptStep {
  content?: string;
  toolCalls?: ToolCall[];
  inputTokens?: number;
  outputTokens?: number;
}

class ScriptedModel implements Model {
  private next = 0;

  constructor(private readonly steps: ScriptStep[]) {}

  async generate(_request: Request): Promise<Response> {
    if (this.next >= this.steps.length) {
      throw new Error("script exhausted");
    }
    const step = this.steps[this.next];
    this.next += 1;
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: step.content ?? "",
        toolCalls: step.toolCalls ?? [],
      },
      usage: usage(step.inputTokens ?? 0, step.outputTokens ?? 0),
    };
  }
}

class EchoTool implements Tool {
  constructor(
    readonly name: string,
    readonly description: string,
    private readonly counter: { value: number }
  ) {}

  invoke(args: Record<string, unknown>): unknown {
    this.counter.value += 1;
    return args;
  }
}

class RecordingSink implements Sink {
  readonly types: string[] = [];

  async emit(event: Event): Promise<void> {
    this.types.push(event.type);
  }
}

export async function runAgentLoop(vector: Vector): Promise<void> {
  const input = vector.input;
  const exp = vector.expect;
  const counter = { value: 0 };
  const registry = new Registry();
  for (const tool of (input.tools as { name: string; description?: string }[]) ??
    []) {
    registry.register(
      new EchoTool(tool.name, tool.description ?? "", counter)
    );
  }
  const sink = new RecordingSink();
  const options: AgentOptions = {
    model: new ScriptedModel((input.script as ScriptStep[]) ?? []),
    tools: registry,
    events: sink,
    maxSteps: Number(input.maxSteps ?? 0),
    maxTokens: Number(input.maxTokens ?? 0),
  };
  const agent = new Agent(options);
  let error: unknown = null;
  let result = null;
  try {
    result = await agent.run(
      { id: "s1" } as Session,
      String(input.prompt ?? "")
    );
  } catch (caught) {
    error = caught;
  }

  if (exp.error) {
    check(error !== null, "expected an error");
    if (exp.errorCode) {
      check(error instanceof PraxoError, `error: got ${String(error)}`);
      check(
        (error as PraxoError).code === exp.errorCode,
        `errorCode: got ${(error as PraxoError).code}`
      );
    }
  } else {
    check(error === null, `unexpected error: ${String(error)}`);
  }

  if (result) {
    check(
      result.output === (exp.output ?? ""),
      `output: got ${JSON.stringify(result.output)}`
    );
    check(
      result.steps === Number(exp.steps ?? 0),
      `steps: got ${result.steps}`
    );
  }
  check(
    counter.value === Number(exp.toolInvocations ?? 0),
    `tool invocations: got ${counter.value}`
  );
  const events = sink.types.length ? sink.types : null;
  check(
    JSON.stringify(events) === JSON.stringify(exp.events ?? null),
    `events: got ${JSON.stringify(events)}`
  );
}

function check(condition: boolean, detail: string): void {
  if (!condition) throw new Error(detail);
}
