module praxo.middleware;

import std.regex : regex, replaceAll, RegexException;
import std.string : replace, strip, indexOf;
import praxo.errors : PraxoError;
import praxo.json;
import praxo.jsonschema;
import praxo.models;

class PiiRedactor {
    private immutable string EMAIL = `[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}`;

    string redact(string text) {
        try {
            return replaceAll(text, regex(EMAIL), "[REDACTED:email]");
        } catch (RegexException) {
            return text;
        }
    }

    JSONValue redactValue(JSONValue value) {
        if (value.type == JSONType.string) return JSONValue(redact(value.str));
        if (value.type == JSONType.array) {
            JSONValue[] result;
            foreach (item; value.array) result ~= redactValue(item);
            return JSONValue(result);
        }
        if (value.type == JSONType.object) {
            JSONValue[string] result;
            foreach (key, item; value.object) result[key] = redactValue(item);
            return JSONValue(result);
        }
        return value;
    }
}

struct StructuredResult {
    string output;
    string errorCode;
}

class StructuredOutput {
    JSONValue schema;
    long maxRepairs;
    string delegate(string) repairer;

    this(JSONValue schema, long maxRepairs = 0, string delegate(string) repairer = null) {
        this.schema = schema;
        this.maxRepairs = maxRepairs;
        this.repairer = repairer;
    }

    StructuredResult apply(string text) {
        auto output = text;
        for (long attempt = 0; attempt <= maxRepairs; attempt++) {
            auto jsonText = extractJson(output);
            if (jsonText !is null) {
                try {
                    auto data = parse(jsonText);
                    if (validate(schema, data).length == 0) return StructuredResult(output, null);
                } catch (Exception) {}
            }
            if (attempt == maxRepairs && repairer is null) break;
            if (repairer is null) break;
            auto repaired = repairer(output);
            if (repaired is null || repaired.strip().length == 0) break;
            output = repaired;
        }
        return StructuredResult(null, "AGENT_STRUCTURED_OUTPUT");
    }

    private string extractJson(string text) {
        auto value = text.strip();
        if (value.length >= 3 && value[0 .. 3] == "```") {
            auto newline = value.indexOf("\n");
            if (newline >= 0) value = value[newline + 1 .. $];
            value = value.replace("`", "").strip();
        }
        auto object = value.indexOf("{");
        auto array = value.indexOf("[");
        if (object < 0 && array < 0) return null;
        if (object < 0) return value[array .. $];
        if (array < 0) return value[object .. $];
        return value[(object < array ? object : array) .. $];
    }
}

class CallLimit {
    long modelLimit;
    long toolLimit;
    long models = 0;
    long tools = 0;

    this(long modelLimit, long toolLimit) {
        this.modelLimit = modelLimit;
        this.toolLimit = toolLimit;
    }

    void beforeModel() {
        models++;
        if (modelLimit > 0 && models > modelLimit) {
            throw new PraxoError("AGENT_MODEL_CALL_LIMIT", "model call limit");
        }
    }

    void beforeTool() {
        tools++;
        if (toolLimit > 0 && tools > toolLimit) {
            throw new PraxoError("AGENT_TOOL_CALL_LIMIT", "tool call limit");
        }
    }
}

class ToolSelection {
    private string[string] selected;

    this(string[] selected) {
        foreach (name; selected) this.selected[name] = name;
    }

    ToolSpec[] filter(ToolSpec[] tools) {
        ToolSpec[] result;
        foreach (tool; tools) {
            if (tool.name in selected) result ~= tool;
        }
        return result;
    }

    void reject(string name) {
        if (name !in selected) {
            throw new PraxoError("AGENT_TOOL_NOT_SELECTED", "tool not selected");
        }
    }
}

alias ModelHandler = Response delegate(Request);
alias ModelMiddleware = ModelHandler delegate(ModelHandler);

ModelMiddleware fallbackModel(ModelHandler fallback) {
    return delegate ModelHandler(ModelHandler next) {
        return delegate Response(Request request) {
            try {
                return next(request);
            } catch (Exception error) {
                if (fallback is null) throw error;
                return fallback(request);
            }
        };
    };
}
