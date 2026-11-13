using Praxo.Core;

namespace Praxo.RetryExample;

public static class Program
{
    public static string Run(IModel model, int maxAttempts = 3)
    {
        var options = new AgentOptions(model)
        {
            MaxSteps = 2,
        };
        options.ModelMiddleware.Add(Retry(maxAttempts));
        return new Agent(options)
            .Run(new Session("retry"), "Check the status.")
            .Output;
    }

    public static ModelMiddleware Retry(int maxAttempts)
        => next => request =>
        {
            PraxoException? lastError = null;
            for (var attempt = 1; attempt <= maxAttempts; attempt++)
            {
                try
                {
                    return next(request);
                }
                catch (PraxoException error)
                    when (error.Code == "MODEL_UNAVAILABLE")
                {
                    lastError = error;
                    if (attempt == maxAttempts)
                    {
                        throw;
                    }
                }
            }
            throw lastError
                ?? new PraxoException("MODEL_UNAVAILABLE", "model unavailable");
        };

    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            var recovered = new FlakyModel(2);
            if (Run(recovered) != "status: green" || recovered.Calls != 3)
            {
                Console.Error.WriteLine("transient retry path failed");
                return 1;
            }

            var exhausted = new FlakyModel(3);
            try
            {
                Run(exhausted);
            }
            catch (PraxoException error)
                when (error.Code == "MODEL_UNAVAILABLE" && exhausted.Calls == 3)
            {
                Console.WriteLine("retry test: ok");
                return 0;
            }
            Console.Error.WriteLine("exhausted retry path did not preserve the error");
            return 1;
        }

        Console.WriteLine("Run with --test; wire a real model in Program.Run.");
        return 0;
    }

    private sealed class FlakyModel : IModel
    {
        private readonly int _failures;

        public FlakyModel(int failures)
        {
            _failures = failures;
        }

        public int Calls { get; private set; }

        public Response Generate(Request request)
        {
            Calls += 1;
            if (Calls <= _failures)
            {
                throw new PraxoException("MODEL_UNAVAILABLE", "temporary outage");
            }
            return new Response
            {
                Message = Message.Assistant("status: green"),
            };
        }
    }
}
