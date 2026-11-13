using Praxo.Core;

namespace Praxo.ProviderFallback;

public static class Program
{
    public static string Run(IModel primary, IModel fallback)
    {
        var options = new AgentOptions(primary)
        {
            FallbackModel = fallback,
            SystemPrompt = "You are a concise assistant.",
            MaxSteps = 2,
        };
        return new Agent(options)
            .Run(new Session("provider-fallback"), "Say hello.")
            .Output;
    }

    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            var primary = new StaticModel("primary response");
            var fallback = new StaticModel("fallback response");
            if (Run(primary, fallback) != "primary response" || fallback.Calls != 0)
            {
                Console.Error.WriteLine("primary success path failed");
                return 1;
            }

            var failing = new FailingModel();
            var used = new StaticModel("fallback response");
            if (Run(failing, used) != "fallback response" || failing.Calls != 1 || used.Calls != 1)
            {
                Console.Error.WriteLine("fallback path failed");
                return 1;
            }

            try
            {
                Run(new FailingModel(), new FailingModel());
            }
            catch
            {
                Console.WriteLine("provider fallback test: ok");
                return 0;
            }
            Console.Error.WriteLine("both-failure path did not reject");
            return 1;
        }

        Console.WriteLine("Run with --test; wire real adapters in Program.Run.");
        return 0;
    }

    private sealed class FailingModel : IModel
    {
        public int Calls { get; private set; }

        public Response Generate(Request request)
        {
            Calls += 1;
            throw new PraxoException("MODEL_UNAVAILABLE", "primary unavailable");
        }
    }

    private sealed class StaticModel : IModel
    {
        private readonly string _content;

        public StaticModel(string content)
        {
            _content = content;
        }

        public int Calls { get; private set; }

        public Response Generate(Request request)
        {
            Calls += 1;
            return new Response
            {
                Message = Message.Assistant(_content),
            };
        }
    }
}
