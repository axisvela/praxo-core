using Praxo.Core.Retriever;

namespace Praxo.Tests;

internal static class RetrieverTests
{
    public static int Run()
    {
        var retriever = new FuncRetriever((query, limit) =>
            Task.FromResult(new List<Document>
            {
                new()
                {
                    Id = "doc-1",
                    Content = $"{query}:{limit}",
                    Metadata = new Dictionary<string, string>
                    {
                        ["source"] = "test",
                    },
                    Score = 0.5,
                },
            }));
        var documents = retriever.RetrieveAsync("hello", 3)
            .GetAwaiter().GetResult();
        Check(documents.Count == 1, "retriever count");
        Check(documents[0].Id == "doc-1", "retriever id");
        Check(documents[0].Content == "hello:3", "retriever content");
        Check(documents[0].Metadata["source"] == "test", "retriever metadata");
        Check(documents[0].Score == 0.5, "retriever score");
        return 1;
    }

    private static void Check(bool condition, string detail)
    {
        if (!condition)
        {
            throw new InvalidOperationException(detail);
        }
    }
}
