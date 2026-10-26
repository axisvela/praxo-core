import { ToolNotFoundError } from "./errors";
import { ToolSpec } from "./model";

export interface Tool {
  name: string;
  description: string;
  invoke(args: Record<string, unknown>): Promise<unknown> | unknown;
}

export class FuncTool implements Tool {
  constructor(
    readonly name: string,
    readonly description: string,
    private readonly fn: (
      args: Record<string, unknown>
    ) => Promise<unknown> | unknown
  ) {}

  invoke(args: Record<string, unknown>): Promise<unknown> | unknown {
    return this.fn(args);
  }
}

export class Registry {
  private readonly tools = new Map<string, Tool>();

  register(tool: Tool): void {
    this.tools.set(tool.name, tool);
  }

  get(name: string): Tool {
    const tool = this.tools.get(name);
    if (!tool) throw new ToolNotFoundError(`tool not found: ${name}`);
    return tool;
  }

  specs(): ToolSpec[] {
    return [...this.tools.values()]
      .sort((a, b) => a.name.localeCompare(b.name))
      .map((tool) => ({
        name: tool.name,
        description: tool.description,
      }));
  }

  get size(): number {
    return this.tools.size;
  }
}

export interface GatewayInfo {
  name: string;
  description?: string;
  risk?: string;
}

export interface Gateway {
  execute(
    name: string,
    input: Record<string, unknown>,
    token?: string
  ): Promise<unknown>;
  listTools(): GatewayInfo[];
}

export class GatewayTool implements Tool {
  readonly name: string;
  readonly description: string;

  constructor(
    private readonly gateway: Gateway,
    private readonly info: GatewayInfo
  ) {
    this.name = info.name;
    this.description = info.description ?? "";
  }

  invoke(args: Record<string, unknown>): Promise<unknown> {
    return this.gateway.execute(this.info.name, args);
  }
}

export function newGatewayTools(gateway: Gateway): Tool[] {
  return gateway
    .listTools()
    .slice()
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((info) => new GatewayTool(gateway, info));
}
