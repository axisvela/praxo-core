using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Praxo.Core;

public sealed class RunState
{
    public string RunId { get; set; } = "";

    public string Prompt { get; set; } = "";
}

public sealed class ModelCall
{
    public string RunId { get; set; } = "";

    public string SessionId { get; set; } = "";

    public Request Request { get; set; } = new();

    public bool Skip { get; set; }

    public Response? Response { get; set; }
}

public sealed class MiddlewareToolCall
{
    public string RunId { get; set; } = "";

    public string SessionId { get; set; } = "";

    public ToolCall Call { get; set; } = new();

    public bool Skip { get; set; }

    public JsonNode? Result { get; set; }

    public PraxoException? Error { get; set; }
}

public sealed class ToolResult
{
    public JsonNode? Value { get; set; }

    public PraxoException? Error { get; set; }
}

public interface IMiddleware
{
    string Name => "";

    void BeforeRun(RunState state) { }

    void BeforeModel(ModelCall call) { }

    void AfterModel(ModelCall call, Response response) { }

    void BeforeTool(MiddlewareToolCall call) { }

    void AfterTool(MiddlewareToolCall call, ToolResult result) { }

    void AfterRun(RunResult? result, PraxoException? error) { }
}

public delegate Response ModelHandler(Request request);

public delegate ModelHandler ModelMiddleware(ModelHandler next);

public static class MiddlewareChain
{
    public static List<IMiddleware> Merge(IEnumerable<IMiddleware> items)
    {
        var output = new List<IMiddleware>();
        var positions = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var item in items)
        {
            var name = item.Name;
            if (string.IsNullOrEmpty(name))
            {
                output.Add(item);
                continue;
            }
            if (positions.TryGetValue(name, out var position))
            {
                output[position] = item;
                continue;
            }
            positions[name] = output.Count;
            output.Add(item);
        }
        return output;
    }
}

public sealed class PiiRule
{
    public string Name { get; }

    public Regex Pattern { get; }

    public string Replacement { get; }

    public PiiRule(string name, string pattern, string replacement)
    {
        Name = name;
        Pattern = new Regex(pattern, RegexOptions.Compiled);
        Replacement = replacement;
    }
}

public sealed class PiiRedactor
{
    private readonly List<PiiRule> _rules;

    public PiiRedactor(IEnumerable<PiiRule> rules)
    {
        _rules = rules.ToList();
    }

    public static PiiRedactor Defaults() => new(new[]
    {
        new PiiRule("email", "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}", "[REDACTED:email]"),
        new PiiRule("ssn", "\\b\\d{3}-\\d{2}-\\d{4}\\b", "[REDACTED:ssn]"),
        new PiiRule("credit_card", "\\b(?:\\d{4}[ -]?){3}\\d{4}\\b", "[REDACTED:credit_card]"),
        new PiiRule("phone", "\\b(?:\\+?1[-. ]?)?\\(?\\d{3}\\)?[-. ]?\\d{3}[-. ]?\\d{4}\\b", "[REDACTED:phone]"),
    });

    public string Redact(string text)
    {
        var output = text;
        foreach (var rule in _rules)
        {
            output = rule.Pattern.Replace(
                output,
                string.IsNullOrEmpty(rule.Replacement) ? "[REDACTED]" : rule.Replacement);
        }
        return output;
    }

    public JsonNode? RedactValue(JsonNode? value)
        => value switch
        {
            null => null,
            JsonValue scalar when scalar.TryGetValue<string>(out var text) => JsonValue.Create(Redact(text)),
            JsonArray array => new JsonArray(array.Select(RedactValue).ToArray()),
            JsonObject obj => new JsonObject(obj.Select(pair =>
                new KeyValuePair<string, JsonNode?>(pair.Key, RedactValue(pair.Value)))),
            _ => value.DeepClone(),
        };
}

public sealed class PiiMiddleware : IMiddleware
{
    private readonly PiiRedactor _redactor;

    public PiiMiddleware(PiiRedactor redactor)
    {
        _redactor = redactor;
    }

    public string Name => "pii";

    public void BeforeModel(ModelCall call)
    {
        call.Request.Messages = call.Request.Messages.Select(message => new Message
        {
            Role = message.Role,
            Content = _redactor.Redact(message.Content ?? ""),
            ContentBlocks = message.ContentBlocks.Select(block => new ContentBlock
            {
                Type = block.Type,
                Text = _redactor.Redact(block.Text ?? ""),
                ImageUrl = block.ImageUrl,
                Data = block.Data,
            }).ToList(),
            ToolCalls = message.ToolCalls,
            ToolId = message.ToolId,
        }).ToList();
    }

    public void AfterTool(MiddlewareToolCall call, ToolResult result)
    {
        result.Value = _redactor.RedactValue(result.Value);
    }
}

public sealed class StructuredOutput : IMiddleware
{
    public const string StrategyAuto = "auto";
    public const string StrategyProvider = "provider";
    public const string StrategyTool = "tool";

    public JsonObject Schema { get; }

    public string OutputName { get; }

    public string Strategy { get; }

    public int MaxRepairs { get; }

    public Func<string, PraxoException, string>? Repairer { get; set; }

    public StructuredOutput(JsonObject schema, string name = "", string strategy = StrategyAuto, int maxRepairs = 0)
    {
        Schema = schema;
        OutputName = string.IsNullOrWhiteSpace(name) ? "structured_output" : name.Trim();
        Strategy = strategy;
        MaxRepairs = maxRepairs;
    }

    public string Name => "structured-output";

    public void Apply(RunResult result)
    {
        var output = result.Output;
        PraxoException? lastError = null;
        for (var attempt = 0; attempt <= MaxRepairs; attempt++)
        {
            try
            {
                ValidateOutput(output);
                result.Output = output;
                return;
            }
            catch (PraxoException ex)
            {
                lastError = ex;
            }
            if (attempt == MaxRepairs || Repairer == null)
            {
                break;
            }
            var repaired = Repairer(output, lastError!);
            if (string.IsNullOrWhiteSpace(repaired))
            {
                throw PraxoException.StructuredOutput(
                    "agent: structured output validation failed: repair returned empty output");
            }
            output = repaired;
        }
        throw PraxoException.StructuredOutput(
            $"agent: structured output validation failed: {lastError?.Message}");
    }

    public void BeforeModel(ModelCall call)
    {
        if (call.Request.ResponseFormat == null && Strategy != StrategyTool && Schema.Count > 0)
        {
            call.Request.ResponseFormat = new ResponseFormat { Name = OutputName, Schema = Schema };
        }
        if (Strategy == StrategyTool && call.Request.Tools.Any(spec => spec.Name == OutputName))
        {
            call.Request.ToolChoice = "required";
        }
    }

    public void AfterRun(RunResult? result, PraxoException? error)
    {
        if (error == null && result != null)
        {
            Apply(result);
        }
    }

    private void ValidateOutput(string output)
    {
        var data = ExtractJson(output);
        var errors = JsonSchema.Validate(Schema, data);
        if (errors.Count > 0)
        {
            throw PraxoException.StructuredOutput($"schema: {errors.Count} error(s)");
        }
    }

    public static JsonNode? ExtractJson(string output)
    {
        var text = output.Trim();
        if (text.Length == 0)
        {
            throw PraxoException.StructuredOutput("empty output");
        }
        if (text.StartsWith("```", StringComparison.Ordinal))
        {
            var newline = text.IndexOf('\n');
            if (newline >= 0)
            {
                text = text[(newline + 1)..];
            }
            text = text.TrimEnd('`').Trim();
        }
        var start = text.IndexOfAny(new[] { '{', '[' });
        if (start < 0)
        {
            throw PraxoException.StructuredOutput("output does not contain JSON");
        }
        return Json.Parse(text[start..]);
    }
}

public sealed class CallLimitMiddleware : IMiddleware
{
    private readonly int _modelLimit;
    private readonly int _toolLimit;
    private readonly Dictionary<string, (int Models, int Tools)> _counts = new(StringComparer.Ordinal);

    public CallLimitMiddleware(int modelLimit, int toolLimit)
    {
        _modelLimit = modelLimit;
        _toolLimit = toolLimit;
    }

    public string Name => "call-limit";

    public void BeforeRun(RunState state)
    {
        _counts[state.RunId] = (0, 0);
    }

    public void BeforeModel(ModelCall call)
    {
        var count = _counts.GetValueOrDefault(call.RunId);
        count.Models++;
        _counts[call.RunId] = count;
        if (_modelLimit > 0 && count.Models > _modelLimit)
        {
            throw PraxoException.ModelCallLimit();
        }
    }

    public void BeforeTool(MiddlewareToolCall call)
    {
        var count = _counts.GetValueOrDefault(call.RunId);
        count.Tools++;
        _counts[call.RunId] = count;
        if (_toolLimit > 0 && count.Tools > _toolLimit)
        {
            throw PraxoException.ToolCallLimit();
        }
    }

    public void AfterRun(RunResult? result, PraxoException? error)
    {
        if (result != null)
        {
            _counts.Remove(result.RunId);
        }
    }
}

public interface IToolSelector
{
    List<string> Select(string query, IReadOnlyList<ToolSpec> tools);
}

public sealed class ToolSelectionMiddleware : IMiddleware
{
    private readonly IToolSelector _selector;
    private readonly Dictionary<string, HashSet<string>> _selected = new(StringComparer.Ordinal);

    public ToolSelectionMiddleware(IToolSelector selector)
    {
        _selector = selector;
    }

    public string Name => "tool-selection";

    public void BeforeModel(ModelCall call)
    {
        var names = _selector.Select(LastUserMessage(call.Request.Messages), call.Request.Tools);
        var chosen = names.ToHashSet(StringComparer.Ordinal);
        _selected[call.RunId] = chosen;
        call.Request.Tools = call.Request.Tools.Where(spec => chosen.Contains(spec.Name)).ToList();
    }

    public void BeforeTool(MiddlewareToolCall call)
    {
        if (_selected.TryGetValue(call.RunId, out var chosen) && !chosen.Contains(call.Call.Name))
        {
            throw PraxoException.ToolNotSelected();
        }
    }

    public void AfterRun(RunResult? result, PraxoException? error)
    {
        if (result != null)
        {
            _selected.Remove(result.RunId);
        }
    }

    public static string LastUserMessage(IReadOnlyList<Message> messages)
        => messages.LastOrDefault(message => message.Role == Roles.User)?.Content ?? "";
}

public static class ModelFallback
{
    public static ModelMiddleware Fallback(IModel? fallback)
        => next => request =>
        {
            try
            {
                return next(request);
            }
            catch (PraxoException primary)
            {
                if (fallback == null)
                {
                    throw;
                }
                try
                {
                    return fallback.Generate(request);
                }
                catch (PraxoException)
                {
                    throw primary;
                }
            }
        };

    public static ModelMiddleware FallbackWithContent(string content)
        => Fallback(new StaticModel(content));
}
