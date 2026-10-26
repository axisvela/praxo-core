module praxo.json;

public import std.json : JSONValue, JSONType, JSONOptions, parseJSON;

JSONValue parse(string text) {
    return parseJSON(text, -1, JSONOptions.strictParsing);
}

string stringify(JSONValue value) {
    return value.toString();
}

JSONValue get(JSONValue node, string key) {
    if (node.type == JSONType.object && key in node.object) {
        return node.object[key];
    }
    return JSONValue(null);
}

bool hasKey(JSONValue node, string key) {
    return node.type == JSONType.object && key in node.object;
}

string getString(JSONValue node, string key) {
    auto value = get(node, key);
    return value.type == JSONType.string ? value.str : null;
}

bool getBool(JSONValue node, string key, bool fallback = false) {
    auto value = get(node, key);
    return value.type == JSONType.true_ || value.type == JSONType.false_ ? value.boolean : fallback;
}

long getInt(JSONValue node, string key, long fallback = 0) {
    auto value = get(node, key);
    if (value.type == JSONType.integer) return value.integer;
    if (value.type == JSONType.uinteger) return cast(long) value.uinteger;
    if (value.type == JSONType.float_) return cast(long) value.floating;
    return fallback;
}

JSONValue[] getArray(JSONValue node, string key) {
    auto value = get(node, key);
    return value.type == JSONType.array ? value.array : [];
}

bool equals(JSONValue left, JSONValue right) {
    if (left.type != right.type) {
        if (left.type == JSONType.integer && right.type == JSONType.float_) {
            return cast(double) left.integer == right.floating;
        }
        if (left.type == JSONType.float_ && right.type == JSONType.integer) {
            return left.floating == cast(double) right.integer;
        }
        return false;
    }
    switch (left.type) {
        case JSONType.null_:
            return true;
        case JSONType.true_:
        case JSONType.false_:
            return left.boolean == right.boolean;
        case JSONType.integer:
            return left.integer == right.integer;
            return left.uinteger == right.uinteger;
        case JSONType.float_:
            return left.floating == right.floating;
        case JSONType.string:
            return left.str == right.str;
        case JSONType.array:
            if (left.array.length != right.array.length) return false;
            foreach (index, item; left.array) {
                if (!equals(item, right.array[index])) return false;
            }
            return true;
        case JSONType.object:
            if (left.object.length != right.object.length) return false;
            foreach (key, item; left.object) {
                if (key !in right.object) return false;
                if (!equals(item, right.object[key])) return false;
            }
            return true;
        default:
            return false;
    }
}

size_t utf8Length(string text) {
    size_t count = 0;
    foreach (c; cast(const(ubyte)[]) text) {
        if ((c & 0xC0) != 0x80) count++;
    }
    return count;
}
