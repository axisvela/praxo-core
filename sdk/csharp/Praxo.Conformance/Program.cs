using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Conformance;

internal static class Program
{
    public static int Main(string[] args)
    {
        if (args.Contains("--api-snapshot"))
        {
            Console.Write(ApiSnapshot.Dump());
            return 0;
        }
        if (args.Contains("--check-api"))
        {
            return CheckApi();
        }
        var root = FindRoot();
        if (root == null)
        {
            Console.Error.WriteLine("cannot find repository root (spec/SPEC_VERSION)");
            return 2;
        }
        var failures = RunAll(root);
        if (failures.Count == 0)
        {
            Console.WriteLine("all spec vectors passed");
            return 0;
        }
        foreach (var failure in failures)
        {
            Console.Error.WriteLine(failure);
        }
        return 1;
    }

    private static int CheckApi()
    {
        var root = FindRoot();
        if (root == null)
        {
            Console.Error.WriteLine("cannot find repository root");
            return 2;
        }
        var path = Path.Combine(root, "sdk", "csharp", "api-snapshot.txt");
        if (!File.Exists(path))
        {
            Console.Error.WriteLine($"missing API snapshot: {path}");
            return 2;
        }
        var expected = File.ReadAllText(path).Replace("\r\n", "\n");
        var actual = ApiSnapshot.Dump().Replace("\r\n", "\n");
        if (expected == actual)
        {
            Console.WriteLine("api snapshot ok");
            return 0;
        }
        Console.Error.WriteLine("api snapshot mismatch; run: dotnet run --project csharp/Praxo.Conformance -- --api-snapshot > csharp/api-snapshot.txt");
        return 1;
    }

    private static List<string> RunAll(string root)
    {
        var version = File.ReadAllText(Path.Combine(root, "spec", "SPEC_VERSION")).Trim();
        var failures = new List<string>();
        var seen = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var path in Directory.GetFiles(Path.Combine(root, "spec", "vectors"), "*.json")
                     .OrderBy(path => path, StringComparer.Ordinal))
        {
            var name = Path.GetFileNameWithoutExtension(path);
            JsonObject file;
            try
            {
                file = Json.Parse(File.ReadAllText(path)) as JsonObject
                    ?? throw new ConformanceException("vector file must be an object");
            }
            catch (Exception ex) when (ex is ConformanceException or System.Text.Json.JsonException)
            {
                failures.Add($"{name}: {ex.Message}");
                continue;
            }
            var group = Json.GetString(file, "group") ?? "";
            if (Json.GetString(file, "specVersion") != version)
            {
                failures.Add($"{name}: specVersion mismatch");
            }
            if (name != group)
            {
                failures.Add($"{name}: group mismatch");
            }
            foreach (var vector in Json.Array(Json.Get(file, "vectors")))
            {
                if (vector == null)
                {
                    failures.Add($"{group}: null vector");
                    continue;
                }
                var id = Json.GetString(vector, "id") ?? "";
                if (seen.TryGetValue(id, out var previous))
                {
                    failures.Add($"{group}/{id}: duplicate id with {previous}");
                }
                seen[id] = group;
                try
                {
                    VectorRunners.Run(group, vector);
                }
                catch (Exception ex) when (ex is ConformanceException or PraxoException)
                {
                    failures.Add($"{group}/{id}: {ex.Message}");
                }
            }
        }
        return failures;
    }

    internal static string? FindRoot()
    {
        var starts = new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory };
        foreach (var start in starts)
        {
            var current = new DirectoryInfo(start);
            while (current != null)
            {
                if (File.Exists(Path.Combine(current.FullName, "spec", "SPEC_VERSION")))
                {
                    return current.FullName;
                }
                current = current.Parent;
            }
        }
        return null;
    }
}
