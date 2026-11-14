using System.Text.Json.Nodes;

using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.LiveModel;

public static class Program
{
    private sealed class TimeTool : ITool, IToolSpecProvider
    {
        public string Name => "get_time";

        public string Description =>
            "Return the current time in ISO 8601 format for the requested zone.";

        public JsonNode? Invoke(JsonObject arguments)
        {
            var zone = arguments["zone"]?.GetValue<string>();
            return JsonValue.Create(
                zone == "local"
                    ? DateTimeOffset.Now.ToString("O")
                    : DateTimeOffset.UtcNow.ToString("O"));
        }

        public ToolSpec Spec() => new()
        {
            Name = Name,
            Description = Description,
            Parameters = JsonNode.Parse("""
                {
                  "type": "object",
                  "properties": {
                    "zone": {
                      "type": "string",
                      "enum": ["utc", "local"],
                      "description": "utc or local; defaults to utc"
                    }
                  }
                }
                """)!.AsObject(),
            Risk = "read",
        };
    }

    private sealed class AllowGetTime : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate")
            {
                return Decision.Allow("model generation");
            }
            if (action.Kind == "tool.invoke")
            {
                return action.ToolName == "get_time"
                    ? Decision.Allow("get_time is permitted")
                    : Decision.Deny("only get_time is permitted");
            }
            return Decision.Deny("unsupported action");
        }
    }

    private static string EnvOr(string name, string fallback)
        => string.IsNullOrEmpty(Environment.GetEnvironmentVariable(name))
            ? fallback
            : Environment.GetEnvironmentVariable(name)!;

    public static int Main()
    {
        var baseUrl = EnvOr("PRAXO_BASE_URL", "http://localhost:11434/v1");
        var modelName = EnvOr("PRAXO_MODEL", "qwen3.5:4b");
        var prompt = EnvOr(
            "PRAXO_PROMPT",
            "What time is it? Use get_time with zone set to utc and reply with the time.");

        var model = new OpenAiCompatibleModel(
            new HttpClient { Timeout = TimeSpan.FromSeconds(120) },
            new OpenAiCompatibleOptions
            {
                BaseUrl = baseUrl,
                ApiKey = EnvOr("PRAXO_API_KEY", ""),
                Model = modelName,
            });

        var tools = new ToolRegistry();
        tools.Register(new TimeTool());

        var options = new AgentOptions(model)
        {
            Tools = tools,
            SystemPrompt =
                "You are a concise assistant. Use the provided tools when they help.",
            MaxSteps = 4,
            AllowedTools = new List<string> { "get_time" },
            Policy = new AllowGetTime(),
        };

        try
        {
            var result = new Agent(options).Run(new Session("live-model"), prompt);
            Console.WriteLine(result.Output);
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(
                $"live model run failed: {error.Message}\n\n" +
                $"Check PRAXO_BASE_URL ({baseUrl}), PRAXO_MODEL ({modelName}), and PRAXO_API_KEY");
            return 1;
        }
    }
}
