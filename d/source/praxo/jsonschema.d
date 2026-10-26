module praxo.jsonschema;

import std.array : join;
import std.conv : to;
import std.regex : regex, matchFirst, RegexException;
import std.utf : count;
import praxo.json;

struct ValidationError {
    string path;
    string message;
}

ValidationError[] validate(JSONValue schema, JSONValue data) {
    ValidationError[] errors;
    visit(schema, data, "$", errors);
    return errors;
}

private void add(ref ValidationError[] errors, string path, string message) {
    errors ~= ValidationError(path, message);
}

private bool patternMatch(string pattern, string text) {
    try {
        return matchFirst(text, regex(pattern)) ? true : false;
    } catch (RegexException) {
        return false;
    }
}

private void checkEnum(JSONValue schema, JSONValue data, string path, ref ValidationError[] errors) {
    auto values = get(schema, "enum");
    if (values.type != JSONType.array) return;
    foreach (value; values.array) {
        if (equals(value, data)) return;
    }
    add(errors, path, "value not in enum");
}

private void visit(JSONValue schema, JSONValue data, string path, ref ValidationError[] errors) {
    if (schema.type != JSONType.object) return;
    auto kind = getString(schema, "type");
    if (kind is null) kind = "";
    if (data.type == JSONType.null_) {
        if (kind.length > 0) add(errors, path, "expected " ~ kind ~ ", got null");
        return;
    }
    if (kind == "object") {
        if (data.type != JSONType.object) {
            add(errors, path, "expected object");
            return;
        }
        auto required = get(schema, "required");
        if (required.type == JSONType.array) {
            foreach (item; required.array) {
                if (item.type != JSONType.string) continue;
                if (!hasKey(data, item.str)) {
                    add(errors, path ~ "." ~ item.str, "required field missing");
                }
            }
        }
        auto properties = get(schema, "properties");
        if (properties.type == JSONType.object) {
            foreach (name, child; properties.object) {
                if (hasKey(data, name)) visit(child, data.object[name], path ~ "." ~ name, errors);
            }
        }
        return;
    }
    if (kind == "array") {
        if (data.type != JSONType.array) {
            add(errors, path, "expected array");
            return;
        }
        auto items = get(schema, "items");
        foreach (index, item; data.array) {
            visit(items, item, path ~ "[" ~ index.to!string ~ "]", errors);
        }
        return;
    }
    if (kind == "string") {
        if (data.type != JSONType.string) {
            add(errors, path, "expected string");
            return;
        }
        auto length = count(data.str);
        auto min = getInt(schema, "minLength");
        auto max = getInt(schema, "maxLength");
        if (min > 0 && length < min) add(errors, path, "min length " ~ min.to!string ~ ", got " ~ length.to!string);
        if (max > 0 && length > max) add(errors, path, "max length " ~ max.to!string ~ ", got " ~ length.to!string);
        auto pattern = getString(schema, "pattern");
        if (pattern !is null && !patternMatch(pattern, data.str)) {
            add(errors, path, "pattern '" ~ pattern ~ "' not matched");
        }
        checkEnum(schema, data, path, errors);
        return;
    }
    if (kind == "number" || kind == "integer") {
        double number;
        if (data.type == JSONType.integer) number = cast(double) data.integer;
        else if (data.type == JSONType.uinteger) number = cast(double) data.uinteger;
        else if (data.type == JSONType.float_) number = data.floating;
        else {
            add(errors, path, "expected number");
            return;
        }
        if (kind == "integer" && number != cast(long) number) {
            add(errors, path, "expected integer, got " ~ number.to!string);
            return;
        }
        checkEnum(schema, data, path, errors);
        auto minimum = get(schema, "minimum");
        if (minimum.type == JSONType.integer && minimum.integer != 0 && number < minimum.integer) {
            add(errors, path, "value below minimum");
        }
        auto maximum = get(schema, "maximum");
        if (maximum.type == JSONType.integer && maximum.integer != 0 && number > maximum.integer) {
            add(errors, path, "value above maximum");
        }
        return;
    }
    if (kind == "boolean") {
        if (data.type != JSONType.true_ && data.type != JSONType.false_) {
            add(errors, path, "expected boolean");
            return;
        }
        checkEnum(schema, data, path, errors);
    }
}
