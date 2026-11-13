namespace Praxo.Core.Retriever;

public sealed class Document
{
    public string Id { get; set; } = "";

    public string Content { get; set; } = "";

    public Dictionary<string, string> Metadata { get; set; } = new();

    public double Score { get; set; }
}

public interface Retriever
{
    Task<List<Document>> RetrieveAsync(string query, int limit);
}

public sealed class FuncRetriever : Retriever
{
    private readonly Func<string, int, Task<List<Document>>> _retrieve;

    public FuncRetriever(Func<string, int, Task<List<Document>>> retrieve)
    {
        _retrieve = retrieve;
    }

    public Task<List<Document>> RetrieveAsync(string query, int limit)
        => _retrieve(query, limit);
}
