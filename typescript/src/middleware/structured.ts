import { StructuredOutputError } from "../errors";
import { Schema, validate } from "../jsonschema";
import { ResponseFormat, ToolSpec } from "../model";
import {
  MaybePromise,
  Middleware,
  ModelCall,
  maybeAwait,
} from "./base";

export const STRATEGY_AUTO = "auto";
export const STRATEGY_PROVIDER = "provider";
export const STRATEGY_TOOL = "tool";

export interface StructuredOutputOptions {
  schema?: Record<string, unknown>;
  name?: string;
  strategy?: string;
  maxRepairs?: number;
  validate?: (output: string) => MaybePromise<void>;
  repair?: (
    output: string,
    error: unknown
  ) => MaybePromise<string>;
}

export class StructuredOutput {
  readonly schema: Record<string, unknown>;
  readonly name: string;
  readonly strategy: string;
  readonly maxRepairs: number;
  readonly validateOutput?: (output: string) => MaybePromise<void>;
  readonly repair?: (
    output: string,
    error: unknown
  ) => MaybePromise<string>;

  constructor(options: StructuredOutputOptions = {}) {
    this.schema = options.schema ?? {};
    this.name = options.name ?? "";
    this.strategy = options.strategy ?? STRATEGY_AUTO;
    this.maxRepairs = options.maxRepairs ?? 0;
    this.validateOutput = options.validate;
    this.repair = options.repair;
  }

  outputName(): string {
    return this.name.trim() || "structured_output";
  }

  responseFormat(): ResponseFormat | undefined {
    if (this.strategy === STRATEGY_TOOL || !Object.keys(this.schema).length) {
      return undefined;
    }
    return { name: this.outputName(), schema: this.schema };
  }

  toolSpec(): ToolSpec {
    return {
      name: this.outputName(),
      description:
        "Return the final answer as structured JSON matching the " +
        "response schema.",
      parameters: this.schema,
      risk: "low",
    };
  }

  middleware(): Middleware {
    const self = this;
    return {
      name: "structured-output",
      beforeModel(call: ModelCall): void {
        if (!call.request.responseFormat) {
          call.request.responseFormat = self.responseFormat();
        }
        if (self.strategy === STRATEGY_TOOL) {
          if (
            (call.request.tools ?? []).some(
              (spec) => spec.name === self.outputName()
            )
          ) {
            call.request.toolChoice = "required";
          }
        }
      },
      async afterRun(result: unknown, error: unknown): Promise<void> {
        if (error || !result) return;
        await self.apply(result as { output: string });
      },
    };
  }

  async apply(result: { output: string }): Promise<void> {
    let output = result.output;
    let lastError: unknown;
    for (let attempt = 0; attempt <= this.maxRepairs; attempt += 1) {
      try {
        await this.runValidation(output);
        result.output = output;
        return;
      } catch (error) {
        lastError = error;
      }
      if (attempt === this.maxRepairs || !this.repair) break;
      const repaired = await maybeAwait(
        this.repair(output, lastError)
      );
      if (!repaired.trim()) {
        throw new StructuredOutputError(
          "agent: structured output validation failed: " +
            "repair returned empty output"
        );
      }
      output = repaired;
    }
    throw new StructuredOutputError(
      `agent: structured output validation failed: ${String(lastError)}`
    );
  }

  async validateArguments(
    args: Record<string, unknown>
  ): Promise<void> {
    if (this.validateOutput) {
      await maybeAwait(this.validateOutput(JSON.stringify(args)));
      return;
    }
    const errors = validate(this.schema as Schema, args);
    if (errors.length) {
      throw new StructuredOutputError(
        `schema: ${errors.map((item) => `${item.path}: ${item.message}`).join(", ")}`
      );
    }
  }

  private async runValidation(output: string): Promise<void> {
    if (this.validateOutput) {
      await maybeAwait(this.validateOutput(output));
      return;
    }
    const data = extractJson(output);
    const errors = validate(this.schema as Schema, data);
    if (errors.length) {
      throw new StructuredOutputError(
        `schema: ${errors.map((item) => `${item.path}: ${item.message}`).join(", ")}`
      );
    }
  }
}

export function extractJson(output: string): unknown {
  let text = output.trim();
  if (!text) throw new Error("empty output");
  if (text.startsWith("```")) {
    const newline = text.indexOf("\n");
    if (newline >= 0) text = text.slice(newline + 1);
    text = text.replace(/```\s*$/, "").trim();
  }
  const start = firstIndex(text, "{", "[");
  if (start < 0) throw new Error("output does not contain JSON");
  text = text.slice(start);
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`decode JSON: ${String(error)}`);
  }
}

function firstIndex(text: string, ...needles: string[]): number {
  const indexes = needles
    .map((needle) => text.indexOf(needle))
    .filter((index) => index >= 0);
  return indexes.length ? Math.min(...indexes) : -1;
}
