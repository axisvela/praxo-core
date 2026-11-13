using Praxo.Core;

namespace Praxo.Streaming;

public static class Program
{
    public static string Run(IModel model, Action<string> onDelta)
    {
        var options = new AgentOptions(model)
        {
            SystemPrompt = "Answer with the current status.",
            MaxSteps = 2,
        };
        return new Agent(options)
            .RunStream(new Session("streaming"), "Check the status.", onDelta)
            .Output;
    }

    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            var chunks = new[] { "status: ", "green" };
            var received = new List<string>();
            var output = Run(new StreamingModel(chunks), received.Add);
            if (output != "status: green")
            {
                Console.Error.WriteLine($"unexpected output: {output}");
                return 1;
            }
            if (!received.SequenceEqual(chunks))
            {
                Console.Error.WriteLine(
                    $"unexpected deltas: {string.Join(", ", received)}");
                return 1;
            }
            if (string.Concat(received) != output)
            {
                Console.Error.WriteLine("deltas do not reconstruct the output");
                return 1;
            }
            Console.WriteLine("streaming test: ok");
            return 0;
        }

        Console.WriteLine("Run with --test; wire a real streaming model in Program.Run.");
        return 0;
    }

    private sealed class StreamingModel : IStreamingModel
    {
        private readonly IReadOnlyList<string> _chunks;

        public StreamingModel(IReadOnlyList<string> chunks)
        {
            _chunks = chunks;
        }

        public Response Generate(Request request)
            => new() { Message = Message.Assistant(string.Concat(_chunks)) };

        public Response GenerateStream(Request request, Action<string> onDelta)
        {
            foreach (var chunk in _chunks)
            {
                onDelta(chunk);
            }
            return Generate(request);
        }
    }
}
