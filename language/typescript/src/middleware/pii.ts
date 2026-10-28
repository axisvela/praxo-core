import {
  Middleware,
  MiddlewareToolCall,
  ModelCall,
  ToolResult,
} from "./base";

export interface PIIRule {
  name: string;
  pattern: RegExp;
  replacement: string;
}

export function newPiiRule(
  name: string,
  pattern: string,
  replacement: string
): PIIRule {
  return { name, pattern: new RegExp(pattern, "g"), replacement };
}

export function defaultPiiRules(): PIIRule[] {
  return [
    newPiiRule(
      "email",
      "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}",
      "[REDACTED:email]"
    ),
    newPiiRule("ssn", "\\b\\d{3}-\\d{2}-\\d{4}\\b", "[REDACTED:ssn]"),
    newPiiRule(
      "credit_card",
      "\\b(?:\\d{4}[ -]?){3}\\d{4}\\b",
      "[REDACTED:credit_card]"
    ),
    newPiiRule(
      "phone",
      "\\b(?:\\+?1[-. ]?)?\\(?\\d{3}\\)?[-. ]?\\d{3}[-. ]?\\d{4}\\b",
      "[REDACTED:phone]"
    ),
  ];
}

export class PIIRedactor {
  constructor(readonly rules: PIIRule[] = []) {}

  redact(text: string): string {
    let out = text;
    for (const rule of this.rules) {
      out = out.replace(
        rule.pattern,
        rule.replacement || "[REDACTED]"
      );
    }
    return out;
  }
}

export function redactValue(
  redactor: PIIRedactor,
  value: unknown
): unknown {
  if (typeof value === "string") return redactor.redact(value);
  if (Buffer.isBuffer(value)) {
    return redactor.redact(value.toString("utf8"));
  }
  if (Array.isArray(value)) {
    return value.map((item) => redactValue(redactor, item));
  }
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(
      value as Record<string, unknown>
    )) {
      out[key] = redactValue(redactor, item);
    }
    return out;
  }
  return value;
}

export function piiMiddleware(redactor: PIIRedactor): Middleware {
  return {
    name: "pii",
    beforeModel(call: ModelCall): void {
      const messages = structuredClone(call.request.messages);
      for (const message of messages) {
        message.content = redactor.redact(message.content ?? "");
        for (const block of message.contentBlocks ?? []) {
          block.text = redactor.redact(block.text ?? "");
        }
        for (const toolCall of message.toolCalls ?? []) {
          toolCall.arguments = redactValue(
            redactor,
            toolCall.arguments
          ) as Record<string, unknown>;
        }
      }
      call.request.messages = messages;
    },
    afterTool(_call: MiddlewareToolCall, result: ToolResult): void {
      result.value = redactValue(redactor, result.value);
    },
  };
}
