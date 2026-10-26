export interface Schema {
  type?: string;
  properties?: Record<string, Schema>;
  required?: string[];
  items?: Schema;
  enum?: unknown[];
  minLength?: number;
  maxLength?: number;
  minimum?: number;
  maximum?: number;
  pattern?: string;
  description?: string;
}

export interface ValidationError {
  path: string;
  message: string;
}

export function fromJson(raw: string): Schema {
  return JSON.parse(raw) as Schema;
}

export function validate(
  schema: Schema | Record<string, unknown>,
  data: unknown
): ValidationError[] {
  const errors: ValidationError[] = [];
  visit(schema as Schema, data, "$", errors);
  return errors;
}

function visit(
  schema: Schema,
  data: unknown,
  path: string,
  errors: ValidationError[]
): void {
  if (data === null || data === undefined) {
    if (schema.type) {
      errors.push({
        path,
        message: `expected ${schema.type}, got null`,
      });
    }
    return;
  }

  if (schema.type === "object") {
    if (!isObject(data)) {
      errors.push({ path, message: "expected object" });
      return;
    }
    for (const name of schema.required ?? []) {
      if (!(name in data)) {
        errors.push({
          path: `${path}.${name}`,
          message: "required field missing",
        });
      }
    }
    for (const [key, child] of Object.entries(schema.properties ?? {})) {
      if (key in data) visit(child, data[key], `${path}.${key}`, errors);
    }
    return;
  }

  if (schema.type === "array") {
    if (!Array.isArray(data)) {
      errors.push({ path, message: "expected array" });
      return;
    }
    if (schema.items) {
      data.forEach((item, index) => {
        visit(schema.items as Schema, item, `${path}[${index}]`, errors);
      });
    }
    return;
  }

  if (schema.type === "string") {
    if (typeof data !== "string") {
      errors.push({ path, message: "expected string" });
      return;
    }
    const length = Array.from(data).length;
    const min = schema.minLength ?? 0;
    const max = schema.maxLength ?? 0;
    if (min > 0 && length < min) {
      errors.push({
        path,
        message: `min length ${min}, got ${length}`,
      });
    }
    if (max > 0 && length > max) {
      errors.push({
        path,
        message: `max length ${max}, got ${length}`,
      });
    }
    if (schema.pattern) {
      try {
        if (!new RegExp(schema.pattern).test(data)) {
          errors.push({
            path,
            message: `pattern '${schema.pattern}' not matched`,
          });
        }
      } catch (error) {
        errors.push({
          path,
          message: `invalid pattern '${schema.pattern}': ${String(error)}`,
        });
      }
    }
    if (schema.enum?.length && !schema.enum.some((item) => item === data)) {
      errors.push({
        path,
        message: `value not in enum: ${JSON.stringify(schema.enum)}`,
      });
    }
    return;
  }

  if (schema.type === "number" || schema.type === "integer") {
    if (typeof data !== "number" || Number.isNaN(data)) {
      errors.push({ path, message: "expected number" });
      return;
    }
    if (schema.type === "integer" && !Number.isInteger(data)) {
      errors.push({ path, message: `expected integer, got ${data}` });
      return;
    }
    if (schema.enum?.length && !schema.enum.some((item) => item === data)) {
      errors.push({
        path,
        message: `value not in enum: ${JSON.stringify(schema.enum)}`,
      });
    }
    const min = schema.minimum ?? 0;
    const max = schema.maximum ?? 0;
    if (min !== 0 && data < min) {
      errors.push({
        path,
        message: `value ${data} below minimum ${min}`,
      });
    }
    if (max !== 0 && data > max) {
      errors.push({
        path,
        message: `value ${data} above maximum ${max}`,
      });
    }
    return;
  }

  if (schema.type === "boolean") {
    if (typeof data !== "boolean") {
      errors.push({ path, message: "expected boolean" });
      return;
    }
    if (schema.enum?.length && !schema.enum.some((item) => item === data)) {
      errors.push({
        path,
        message: `value not in enum: ${JSON.stringify(schema.enum)}`,
      });
    }
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
