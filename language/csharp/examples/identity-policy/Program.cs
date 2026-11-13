using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.IdentityPolicyExample;

public static class Program
{
    private const string SessionId = "session-1";

    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            RunDeterministicTest();
            Console.WriteLine("identity policy test: ok");
            return 0;
        }

        Console.WriteLine("Run with --test; bind verified principals in Program.cs.");
        return 0;
    }

    private static (int Calls, PraxoException? Error) RunCase(
        Principal? principal,
        string claimedTenant = "acme",
        string claimedRole = "admin")
    {
        var store = new PrincipalStore();
        if (principal != null)
        {
            store.Bind(SessionId, principal);
        }
        var calls = 0;
        var tools = new ToolRegistry();
        tools.Register(new FuncTool("record", "Record a target.", _ =>
        {
            calls += 1;
            return JsonValue.Create("recorded");
        }));
        var options = new AgentOptions(new ClaimingModel(claimedTenant, claimedRole))
        {
            Tools = tools,
            Policy = new IdentityPolicy(store),
            AllowedTools = new List<string> { "record" },
            MaxSteps = 3,
        };
        try
        {
            var result = new Agent(options).Run(new Session(SessionId), "record");
            return result.Output == "recorded"
                ? (calls, null)
                : (calls, new PraxoException("TEST", result.Output));
        }
        catch (PraxoException error)
        {
            return (calls, error);
        }
    }

    private static void RunDeterministicTest()
    {
        var cases = new (string Name, Principal? Principal, string Tenant, string Role, bool Allowed)[]
        {
            ("missing", null, "acme", "admin", false),
            ("inactive", new Principal("actor-1", "acme", "operator", false), "acme", "admin", false),
            ("role", new Principal("actor-1", "acme", "viewer", true), "acme", "admin", false),
            ("tenant", new Principal("actor-1", "acme", "operator", true), "other", "admin", false),
            ("operator", new Principal("actor-1", "acme", "operator", true), "acme", "admin", true),
        };
        foreach (var testCase in cases)
        {
            var (calls, error) = RunCase(testCase.Principal, testCase.Tenant, testCase.Role);
            if (testCase.Allowed)
            {
                if (error != null || calls != 1)
                {
                    throw new InvalidOperationException(
                        $"{testCase.Name}: expected allow, calls={calls}, error={error?.Code}");
                }
            }
            else if (error?.Code != "AGENT_POLICY_DENIED" || calls != 0)
            {
                throw new InvalidOperationException(
                    $"{testCase.Name}: expected deny before effect, calls={calls}, error={error?.Code}");
            }
        }
    }

    private sealed record Principal(string Id, string Tenant, string Role, bool Active);

    private sealed class PrincipalStore
    {
        private readonly Dictionary<string, Principal> _principals = new();

        public void Bind(string sessionId, Principal principal)
            => _principals[sessionId] = principal;

        public Principal? Lookup(string sessionId)
            => _principals.GetValueOrDefault(sessionId);
    }

    private sealed class IdentityPolicy : IPolicyHook
    {
        private readonly PrincipalStore _store;

        public IdentityPolicy(PrincipalStore store)
        {
            _store = store;
        }

        public Decision Authorize(Praxo.Core.Action action)
        {
            var principal = _store.Lookup(action.SessionId);
            if (principal == null)
            {
                return Decision.Deny("trusted principal is missing");
            }
            if (!principal.Active)
            {
                return Decision.Deny("trusted principal is inactive");
            }
            if (action.Kind == "model.generate")
            {
                return Decision.Allow("principal may run the agent");
            }
            if (action.Kind != "tool.invoke")
            {
                return Decision.Deny("unsupported action");
            }
            if (principal.Role != "operator")
            {
                return Decision.Deny("role is not permitted");
            }
            if (action.Arguments?["tenant"]?.GetValue<string>() != principal.Tenant)
            {
                return Decision.Deny("tenant does not match the principal");
            }
            if (action.ToolName != "record")
            {
                return Decision.Deny("operation is not permitted");
            }
            return Decision.Allow("verified operator");
        }
    }

    private sealed class ClaimingModel : IModel
    {
        private readonly string _tenant;
        private readonly string _role;

        public ClaimingModel(string tenant, string role)
        {
            _tenant = tenant;
            _role = role;
        }

        public Response Generate(Request request)
        {
            if (request.Messages.LastOrDefault()?.Role == Roles.Tool)
            {
                return new Response { Message = Message.Assistant("recorded") };
            }
            return new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall
                    {
                        Id = "record-1",
                        Name = "record",
                        Arguments = new JsonObject
                        {
                            ["tenant"] = _tenant,
                            ["role"] = _role,
                        },
                    },
                }),
            };
        }
    }
}
