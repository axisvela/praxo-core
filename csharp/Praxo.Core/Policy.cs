namespace Praxo.Core;

public interface IPolicyHook
{
    Decision Authorize(Action action);
}

public sealed class PathChecker
{
    private static readonly string[] AccessLevels = { "read", "write", "readwrite" };

    private readonly List<PathGrant> _grants;

    public PathChecker(IEnumerable<PathGrant> grants)
    {
        _grants = new List<PathGrant>();
        foreach (var grant in grants)
        {
            if (string.IsNullOrEmpty(grant.Root))
            {
                throw PraxoException.Policy("policy: path grant root is required");
            }
            if (!AccessLevels.Contains(grant.Access))
            {
                throw PraxoException.Policy($"policy: invalid grant access {grant.Access}");
            }
            _grants.Add(new PathGrant
            {
                Root = Resolve(grant.Root),
                Access = grant.Access,
            });
        }
    }

    public Decision Check(string target, string need)
    {
        if (!AccessLevels.Contains(need))
        {
            throw PraxoException.Policy($"policy: invalid requested access {need}");
        }
        if (_grants.Count == 0)
        {
            return Decision.Deny("no allowed roots");
        }
        var resolved = Resolve(target);
        string? matched = null;
        foreach (var grant in _grants)
        {
            if (!Within(grant.Root, resolved))
            {
                continue;
            }
            matched = grant.Root;
            if (Allows(grant.Access, need))
            {
                return Decision.Allow($"path within {grant.Root}");
            }
        }
        return matched != null
            ? Decision.Deny($"path within {matched} but the grant is insufficient")
            : Decision.Deny("path outside allowed roots");
    }

    public bool Allowed(string target, string need)
    {
        try
        {
            return Check(target, need).Allowed;
        }
        catch (PraxoException)
        {
            return false;
        }
    }

    private static string Resolve(string value)
    {
        try
        {
            return Path.GetFullPath(value);
        }
        catch (Exception ex) when (ex is ArgumentException or NotSupportedException or PathTooLongException)
        {
            throw PraxoException.Policy($"policy: resolve {value}: {ex.Message}");
        }
    }

    private static bool Within(string root, string target)
    {
        var comparison = OperatingSystem.IsWindows()
            ? StringComparison.OrdinalIgnoreCase
            : StringComparison.Ordinal;
        var normalizedRoot = Path.TrimEndingDirectorySeparator(root);
        var normalizedTarget = Path.TrimEndingDirectorySeparator(target);
        if (string.Equals(normalizedRoot, normalizedTarget, comparison))
        {
            return true;
        }
        var prefix = normalizedRoot + Path.DirectorySeparatorChar;
        return normalizedTarget.StartsWith(prefix, comparison);
    }

    private static bool Allows(string grant, string need)
        => need switch
        {
            "read" => grant is "read" or "readwrite",
            "write" => grant is "write" or "readwrite",
            _ => grant == "readwrite",
        };
}
