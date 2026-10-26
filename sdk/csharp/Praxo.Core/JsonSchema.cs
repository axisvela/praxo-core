using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Praxo.Core;

public sealed record ValidationError(string Path, string Message);

public static class JsonSchema
{
    public static List<ValidationError> Validate(JsonNode? schema, JsonNode? data)
    {
        var errors = new List<ValidationError>();
        Visit(schema as JsonObject ?? new JsonObject(), data, "$", errors);
        return errors;
    }

    private static void Visit(JsonObject schema, JsonNode? data, string path, List<ValidationError> errors)
    {
        var kind = Json.GetString(schema, "type") ?? "";
        if (data == null)
        {
            if (kind.Length > 0)
            {
                errors.Add(new ValidationError(path, $"expected {kind}, got null"));
            }
            return;
        }

        switch (kind)
        {
            case "object":
                VisitObject(schema, data, path, errors);
                break;
            case "array":
                VisitArray(schema, data, path, errors);
                break;
            case "string":
                VisitString(schema, data, path, errors);
                break;
            case "number":
            case "integer":
                VisitNumber(schema, kind, data, path, errors);
                break;
            case "boolean":
                VisitBoolean(schema, data, path, errors);
                break;
        }
    }

    private static void VisitObject(JsonObject schema, JsonNode? data, string path, List<ValidationError> errors)
    {
        if (data is not JsonObject obj)
        {
            errors.Add(new ValidationError(path, "expected object"));
            return;
        }
        foreach (var required in Json.Array(Json.Get(schema, "required")))
        {
            var name = required is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;
            if (name != null && !obj.ContainsKey(name))
            {
                errors.Add(new ValidationError($"{path}.{name}", "required field missing"));
            }
        }
        if (Json.Get(schema, "properties") is JsonObject properties)
        {
            foreach (var pair in properties)
            {
                if (pair.Value == null || !obj.TryGetPropertyValue(pair.Key, out var value))
                {
                    continue;
                }
                Visit(pair.Value as JsonObject ?? new JsonObject(), value, $"{path}.{pair.Key}", errors);
            }
        }
    }

    private static void VisitArray(JsonObject schema, JsonNode? data, string path, List<ValidationError> errors)
    {
        if (data is not JsonArray array)
        {
            errors.Add(new ValidationError(path, "expected array"));
            return;
        }
        if (Json.Get(schema, "items") is JsonObject items)
        {
            for (var index = 0; index < array.Count; index++)
            {
                Visit(items, array[index], $"{path}[{index}]", errors);
            }
        }
    }

    private static void VisitString(JsonObject schema, JsonNode? data, string path, List<ValidationError> errors)
    {
        var text = data is JsonValue value && value.TryGetValue<string>(out var result) ? result : null;
        if (text == null)
        {
            errors.Add(new ValidationError(path, "expected string"));
            return;
        }
        var length = text.EnumerateRunes().Count();
        var min = Json.GetInt(schema, "minLength");
        var max = Json.GetInt(schema, "maxLength");
        if (min > 0 && length < min)
        {
            errors.Add(new ValidationError(path, $"min length {min}, got {length}"));
        }
        if (max > 0 && length > max)
        {
            errors.Add(new ValidationError(path, $"max length {max}, got {length}"));
        }
        var pattern = Json.GetString(schema, "pattern");
        if (pattern != null)
        {
            try
            {
                if (!Regex.IsMatch(text, pattern))
                {
                    errors.Add(new ValidationError(path, $"pattern '{pattern}' not matched"));
                }
            }
            catch (ArgumentException ex)
            {
                errors.Add(new ValidationError(path, $"invalid pattern '{pattern}': {ex.Message}"));
            }
        }
        CheckEnum(schema, data, path, errors);
    }

    private static void VisitNumber(JsonObject schema, string kind, JsonNode? data, string path, List<ValidationError> errors)
    {
        if (data is not JsonValue value || !value.TryGetValue<double>(out var number))
        {
            errors.Add(new ValidationError(path, "expected number"));
            return;
        }
        if (kind == "integer" && number % 1 != 0)
        {
            errors.Add(new ValidationError(path, $"expected integer, got {number}"));
            return;
        }
        CheckEnum(schema, data, path, errors);
        var minimum = Json.GetNumber(schema, "minimum");
        var maximum = Json.GetNumber(schema, "maximum");
        if (minimum != 0 && number < minimum)
        {
            errors.Add(new ValidationError(path, $"value {number} below minimum {minimum}"));
        }
        if (maximum != 0 && number > maximum)
        {
            errors.Add(new ValidationError(path, $"value {number} above maximum {maximum}"));
        }
    }

    private static void VisitBoolean(JsonObject schema, JsonNode? data, string path, List<ValidationError> errors)
    {
        if (data is not JsonValue value || value.GetValueKind() != JsonValueKind.True
            && value.GetValueKind() != JsonValueKind.False)
        {
            errors.Add(new ValidationError(path, "expected boolean"));
            return;
        }
        CheckEnum(schema, data, path, errors);
    }

    private static void CheckEnum(JsonObject schema, JsonNode? data, string path, List<ValidationError> errors)
    {
        if (Json.Get(schema, "enum") is not JsonArray values || values.Count == 0)
        {
            return;
        }
        foreach (var value in values)
        {
            if (Json.DeepEquals(value, data))
            {
                return;
            }
        }
        errors.Add(new ValidationError(path, "value not in enum"));
    }
}
