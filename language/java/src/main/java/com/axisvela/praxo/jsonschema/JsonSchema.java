package com.axisvela.praxo.jsonschema;

import com.axisvela.praxo.util.Json;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;

public final class JsonSchema {
    private JsonSchema() {
    }

    public static List<ValidationError> validate(
            Map<String, Object> schema, Object data) {
        List<ValidationError> errors = new ArrayList<>();
        visit(schema, data, "$", errors);
        return errors;
    }

    private static void visit(
            Map<String, Object> schema,
            Object data,
            String path,
            List<ValidationError> errors) {
        String type = schema.get("type") == null
                ? ""
                : Json.string(schema.get("type"));
        if (data == null) {
            if (!type.isEmpty()) {
                errors.add(new ValidationError(
                        path, "expected " + type + ", got null"));
            }
            return;
        }
        switch (type) {
            case "object" -> visitObject(schema, data, path, errors);
            case "array" -> visitArray(schema, data, path, errors);
            case "string" -> visitString(schema, data, path, errors);
            case "number", "integer" -> visitNumber(schema, type, data, path, errors);
            case "boolean" -> visitBoolean(schema, data, path, errors);
            default -> {
            }
        }
    }

    private static void visitObject(
            Map<String, Object> schema,
            Object data,
            String path,
            List<ValidationError> errors) {
        if (!(data instanceof Map<?, ?> object)) {
            errors.add(new ValidationError(path, "expected object"));
            return;
        }
        Object required = schema.get("required");
        if (required != null) {
            for (Object item : Json.asArray(required)) {
                String name = Json.string(item);
                if (!object.containsKey(name)) {
                    errors.add(new ValidationError(
                            path + "." + name, "required field missing"));
                }
            }
        }
        Object properties = schema.get("properties");
        if (properties != null) {
            Map<String, Object> propertyMap = Json.asObject(properties);
            for (Map.Entry<String, Object> entry : propertyMap.entrySet()) {
                if (object.containsKey(entry.getKey())) {
                    visit(Json.asObject(entry.getValue()),
                            object.get(entry.getKey()),
                            path + "." + entry.getKey(),
                            errors);
                }
            }
        }
    }

    private static void visitArray(
            Map<String, Object> schema,
            Object data,
            String path,
            List<ValidationError> errors) {
        if (!(data instanceof List<?> list)) {
            errors.add(new ValidationError(path, "expected array"));
            return;
        }
        Object items = schema.get("items");
        if (items != null) {
            Map<String, Object> itemSchema = Json.asObject(items);
            for (int index = 0; index < list.size(); index++) {
                visit(itemSchema, list.get(index),
                        path + "[" + index + "]", errors);
            }
        }
    }

    private static void visitString(
            Map<String, Object> schema,
            Object data,
            String path,
            List<ValidationError> errors) {
        if (!(data instanceof String text)) {
            errors.add(new ValidationError(path, "expected string"));
            return;
        }
        int length = text.codePointCount(0, text.length());
        int min = schema.get("minLength") == null
                ? 0 : Json.intValue(schema.get("minLength"));
        int max = schema.get("maxLength") == null
                ? 0 : Json.intValue(schema.get("maxLength"));
        if (min > 0 && length < min) {
            errors.add(new ValidationError(
                    path, "min length " + min + ", got " + length));
        }
        if (max > 0 && length > max) {
            errors.add(new ValidationError(
                    path, "max length " + max + ", got " + length));
        }
        Object pattern = schema.get("pattern");
        if (pattern != null && !Json.string(pattern).isEmpty()) {
            try {
                if (!Pattern.compile(Json.string(pattern)).matcher(text).find()) {
                    errors.add(new ValidationError(
                            path, "pattern '" + Json.string(pattern) + "' not matched"));
                }
            } catch (PatternSyntaxException error) {
                errors.add(new ValidationError(
                        path, "invalid pattern '" + Json.string(pattern) + "': " + error));
            }
        }
        checkEnum(schema, data, path, errors);
    }

    private static void visitNumber(
            Map<String, Object> schema,
            String type,
            Object data,
            String path,
            List<ValidationError> errors) {
        if (!(data instanceof Number number)) {
            errors.add(new ValidationError(path, "expected number"));
            return;
        }
        double value = number.doubleValue();
        if (type.equals("integer") && value != Math.rint(value)) {
            errors.add(new ValidationError(
                    path, "expected integer, got " + value));
            return;
        }
        checkEnum(schema, data, path, errors);
        double min = schema.get("minimum") == null
                ? 0 : Json.number(schema.get("minimum"));
        double max = schema.get("maximum") == null
                ? 0 : Json.number(schema.get("maximum"));
        if (min != 0 && value < min) {
            errors.add(new ValidationError(
                    path, "value " + value + " below minimum " + min));
        }
        if (max != 0 && value > max) {
            errors.add(new ValidationError(
                    path, "value " + value + " above maximum " + max));
        }
    }

    private static void visitBoolean(
            Map<String, Object> schema,
            Object data,
            String path,
            List<ValidationError> errors) {
        if (!(data instanceof Boolean)) {
            errors.add(new ValidationError(path, "expected boolean"));
            return;
        }
        checkEnum(schema, data, path, errors);
    }

    private static void checkEnum(
            Map<String, Object> schema,
            Object data,
            String path,
            List<ValidationError> errors) {
        Object raw = schema.get("enum");
        if (raw == null) {
            return;
        }
        List<Object> values = Json.asArray(raw);
        if (!values.isEmpty() && values.stream().noneMatch(item -> Objects.equals(item, data))) {
            errors.add(new ValidationError(
                    path, "value not in enum: " + Json.stringify(values)));
        }
    }
}
