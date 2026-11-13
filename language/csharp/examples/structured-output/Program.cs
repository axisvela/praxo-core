using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.StructuredOutputExample;

public static class Program
{
    private static readonly JsonObject SummarySchema = JsonNode.Parse("""
        {
          "type": "object",
          "required": ["title", "summary", "tags"],
          "properties": {
            "title": { "type": "string" },
            "summary": { "type": "string" },
            "tags": { "type": "array", "items": { "type": "string" } }
          }
        }
        """)!.AsObject();

    public static string Summarize(string text, IModel? model = null)
    {
        var selected = model ?? new OpenAiCompatibleModel(
            new HttpClient(),
            new OpenAiCompatibleOptions
            {
                BaseUrl = EnvOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
                ApiKey = EnvOr("PRAXO_API_KEY", ""),
                Model = EnvOr("PRAXO_MODEL", "llama3.2"),
            });
        var options = new AgentOptions(selected)
        {
            SystemPrompt =
                "Summarize the supplied text as JSON with title, summary, and tags. " +
                "Return only JSON.",
            StructuredOutput = new StructuredOutput(SummarySchema, "summary"),
        };
        return new Agent(options)
            .Run(new Session("structured-output"), text)
            .Output;
    }

    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            RunDeterministicTest();
            return 0;
        }

        var text = string.Join(" ", args).Trim();
        if (text.Length == 0)
        {
            text = Console.In.ReadToEnd().Trim();
        }
        if (text.Length == 0)
        {
            Console.Error.WriteLine("usage: Praxo.StructuredOutputExample <text>");
            return 2;
        }

        try
        {
            Console.WriteLine(Summarize(text));
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(
                $"structured output run failed: {error.Message}\n\n" +
                "Check PRAXO_BASE_URL, PRAXO_MODEL, and PRAXO_API_KEY");
            return 1;
        }
    }

    private static void RunDeterministicTest()
    {
        var output = Summarize(
            "Quarterly status: all checks green.",
            new FakeModel());
        var data = JsonNode.Parse(output)!.AsObject();
        if (data["title"] is null || data["summary"] is null || data["tags"] is not JsonArray)
        {
            throw new InvalidOperationException("structured output did not match the schema");
        }
        Console.WriteLine("structured output test: ok");
    }

    private static string EnvOr(string name, string fallback)
        => string.IsNullOrEmpty(Environment.GetEnvironmentVariable(name))
            ? fallback
            : Environment.GetEnvironmentVariable(name)!;

    private sealed class FakeModel : IModel
    {
        public Response Generate(Request request) => new()
        {
            Message = Message.Assistant(
                "{\"title\":\"Release status\"," +
                "\"summary\":\"All checks are green.\"," +
                "\"tags\":[\"release\",\"status\"]}"),
        };
    }
}
