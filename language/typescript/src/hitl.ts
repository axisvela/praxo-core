import { ToolCall } from "./model";

export type InterruptAction = "approve" | "edit" | "reject" | "respond";

export const INTERRUPT_APPROVE: InterruptAction = "approve";
export const INTERRUPT_EDIT: InterruptAction = "edit";
export const INTERRUPT_REJECT: InterruptAction = "reject";
export const INTERRUPT_RESPOND: InterruptAction = "respond";

export interface Interrupt {
  runId: string;
  sessionId: string;
  call: ToolCall;
}

export interface InterruptDecision {
  action: InterruptAction | string;
  arguments?: Record<string, unknown>;
  response?: string;
  reason?: string;
}

export type InterruptHandler = (
  interrupt: Interrupt
) => InterruptDecision | Promise<InterruptDecision>;

export type InterruptApproval = (
  interrupt: Interrupt
) => boolean | Promise<boolean>;
