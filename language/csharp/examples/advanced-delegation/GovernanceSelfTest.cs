using System.Text.Json.Nodes;
using Praxo.Core;
using PraxoAction = Praxo.Core.Action;
namespace Praxo.AdvancedDelegation;

internal static class GovernanceSelfTest
{
    private sealed class DelegationException : Exception
    {
        public DelegationException(string message) : base(message)
        {
        }
    }

    private sealed class SharedBudget
    {
        private readonly object _gate = new();
        private int _remaining;

        public SharedBudget(int remaining)
        {
            _remaining = remaining;
        }

        public bool Available()
        {
            lock (_gate)
            {
                return _remaining > 0;
            }
        }

        public bool Take()
        {
            lock (_gate)
            {
                if (_remaining <= 0) return false;
                _remaining -= 1;
                return true;
            }
        }
    }

    private sealed class Authority
    {
        public HashSet<string> Allowed { get; set; } = new(StringComparer.Ordinal);

        public HashSet<string> Delegable { get; set; } = new(StringComparer.Ordinal);

        public int MaxDepth { get; set; }

        public int MaxChildren { get; set; }

        public int Depth { get; set; }

        public SharedBudget Budget { get; set; } = new(1);

        public IPolicyHook? Policy { get; set; }
    }

    private sealed class PolicyChain : IPolicyHook
    {
        private readonly List<IPolicyHook> _hooks;

        public PolicyChain(params IPolicyHook?[] hooks)
        {
            _hooks = hooks.Where(hook => hook is not null).Cast<IPolicyHook>().ToList();
        }

        public Decision Authorize(PraxoAction action)
        {
            foreach (var hook in _hooks)
            {
                var decision = hook.Authorize(action);
                if (!decision.Allowed) return decision;
            }
            return Decision.Allow("delegation policy chain allowed");
        }
    }

    private sealed class BudgetedTool : ITool
    {
        private readonly ITool _inner;
        private readonly SharedBudget _budget;

        public BudgetedTool(ITool inner, SharedBudget budget)
        {
            _inner = inner;
            _budget = budget;
        }

        public string Name => _inner.Name;

        public string Description => _inner.Description;

        public JsonNode? Invoke(JsonObject arguments)
        {
            if (!_budget.Take())
            {
                throw new PraxoException(
                    "DELEGATION_BUDGET", "delegation budget exhausted");
            }
            return _inner.Invoke(arguments);
        }
    }

    private sealed class ChildScope
    {
        private readonly System.Action _release;

        public ChildScope(Authority authority, System.Action release)
        {
            Authority = authority;
            _release = release;
        }

        public Authority Authority { get; }

        public void Release() => _release();

        public RunResult Run(
            IModel model,
            ToolRegistry tools,
            string prompt,
            CancellationToken token = default,
            IEnumerable<IMiddleware>? middleware = null)
        {
            var names = Authority.Allowed
                .OrderBy(name => name, StringComparer.Ordinal)
                .ToList();
            var scoped = new ToolRegistry();
            foreach (var name in names)
            {
                scoped.Register(new BudgetedTool(tools.Get(name), Authority.Budget));
            }
            var options = new AgentOptions(model)
            {
                Tools = scoped,
                MaxSteps = 3,
                AllowedTools = names,
                Policy = Authority.Policy,
                Middleware = (middleware ?? Enumerable.Empty<IMiddleware>()).ToList(),
                CancellationToken = token,
                RequirePolicy = true,
                RequireToolScope = true,
            };
            return new Agent(options).Run(
                new Session("governed-delegation-child"), prompt);
        }
    }

    private sealed class Governor
    {
        private readonly object _gate = new();
        private int _active;

        public Governor(Authority authority)
        {
            Authority = authority;
        }

        public Authority Authority { get; }

        public ChildScope Delegate(
            IEnumerable<string> allowed,
            IEnumerable<string>? delegable = null,
            IPolicyHook? policy = null)
        {
            var allowedSet = new HashSet<string>(allowed, StringComparer.Ordinal);
            var delegableSet = new HashSet<string>(
                delegable ?? Array.Empty<string>(), StringComparer.Ordinal);
            var depth = Authority.Depth + 1;
            if (depth > Authority.MaxDepth)
            {
                throw new DelegationException("delegation depth exceeded");
            }
            if (allowedSet.Count == 0)
            {
                throw new DelegationException("delegation tool scope is empty");
            }
            if (!allowedSet.IsSubsetOf(Authority.Delegable))
            {
                throw new DelegationException("delegation scope exceeds parent");
            }
            if (!allowedSet.IsSubsetOf(Authority.Allowed))
            {
                throw new DelegationException("delegation scope is not allowed");
            }
            if (!delegableSet.IsSubsetOf(Authority.Delegable))
            {
                throw new DelegationException("child delegable scope exceeds parent");
            }
            if (!Authority.Budget.Available())
            {
                throw new DelegationException("delegation budget exhausted");
            }
            lock (_gate)
            {
                if (_active >= Authority.MaxChildren)
                {
                    throw new DelegationException("delegation child limit exceeded");
                }
                _active += 1;
            }
            var released = false;
            void Release()
            {
                lock (_gate)
                {
                    if (released) return;
                    released = true;
                    _active -= 1;
                }
            }
            return new ChildScope(
                new Authority
                {
                    Allowed = allowedSet,
                    Delegable = delegableSet,
                    MaxDepth = Authority.MaxDepth,
                    MaxChildren = Authority.MaxChildren,
                    Depth = depth,
                    Budget = Authority.Budget,
                    Policy = new PolicyChain(Authority.Policy, policy),
                },
                Release);
        }
    }

    private sealed class FixtureModel : IModel
    {
        private readonly string _tool;
        private readonly JsonObject _arguments;
        private readonly string _completion;
        private int _calls;

        public FixtureModel(string tool, JsonObject arguments, string completion)
        {
            _tool = tool;
            _arguments = arguments;
            _completion = completion;
        }

        public Response Generate(Request request)
        {
            _calls += 1;
            if (request.Messages[^1].Role == Roles.Tool)
            {
                return new Response { Message = Message.Assistant(_completion) };
            }
            return new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall
                    {
                        Id = $"call-{_calls}",
                        Name = _tool,
                        Arguments = _arguments.DeepClone().AsObject(),
                    },
                }),
            };
        }
    }

    private sealed class RecordTool : ITool
    {
        public int Calls { get; private set; }

        public string Name => "record";

        public string Description => "Record a child result in an in-memory counter.";

        public JsonNode? Invoke(JsonObject arguments)
        {
            Calls += 1;
            return JsonValue.Create("recorded");
        }
    }

    private sealed class ParentOnlyTool : ITool
    {
        public int Calls { get; private set; }

        public string Name => "parent_only";

        public string Description => "A tool that must remain outside the child scope.";

        public JsonNode? Invoke(JsonObject arguments)
        {
            Calls += 1;
            return JsonValue.Create("parent-effect");
        }
    }

    private static Decision RecordPolicy(PraxoAction action)
    {
        if (action.Kind != "tool.invoke") return Decision.Allow("non-tool action");
        if (action.ToolName != "record")
        {
            return Decision.Deny("child may only record");
        }
        if (action.Arguments?["target"]?.GetValue<string>() == "blocked")
        {
            return Decision.Deny("blocked target");
        }
        return Decision.Allow("record allowed");
    }

    private static Authority RootAuthority(
        IEnumerable<string> allowed,
        IEnumerable<string> delegable,
        int maxDepth,
        int maxChildren,
        int budget)
        => new()
        {
            Allowed = new HashSet<string>(allowed, StringComparer.Ordinal),
            Delegable = new HashSet<string>(delegable, StringComparer.Ordinal),
            MaxDepth = maxDepth,
            MaxChildren = maxChildren,
            Budget = new SharedBudget(budget),
            Policy = new PolicyChain(new AllowAll()),
        };

    private sealed class AllowAll : IPolicyHook
    {
        public Decision Authorize(PraxoAction action) => Decision.Allow("root");
    }

    private sealed class EditMiddleware : IMiddleware
    {
        public void BeforeTool(MiddlewareToolCall call)
        {
            call.Call.Arguments["target"] = "blocked";
        }
    }

    private static void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    public static int Run()
    {
        var record = new RecordTool();
        var tools = new ToolRegistry();
        tools.Register(record);
        var root = new Governor(
            RootAuthority(
                new[] { "record", "parent_only" },
                new[] { "record" },
                1,
                2,
                2));
        try
        {
            root.Delegate(new[] { "parent_only" });
            throw new InvalidOperationException("child escaped the delegable scope");
        }
        catch (DelegationException)
        {
            Check(record.Calls == 0, "scope rejection produced an effect");
        }
        root.Delegate(new[] { "record" }, policy: new RecordPolicyHook()).Release();

        var depthRoot = new Governor(
            RootAuthority(new[] { "record" }, new[] { "record" }, 1, 1, 2));
        var depthChild = depthRoot.Delegate(
            new[] { "record" }, policy: new RecordPolicyHook());
        depthChild.Authority.Delegable = new HashSet<string>(
            new[] { "record" }, StringComparer.Ordinal);
        try
        {
            new Governor(depthChild.Authority).Delegate(new[] { "record" });
            throw new InvalidOperationException("delegation exceeded the depth limit");
        }
        catch (DelegationException)
        {
            depthChild.Release();
        }

        var childLimit = new Governor(
            RootAuthority(new[] { "record" }, new[] { "record" }, 1, 1, 2));
        var firstChild = childLimit.Delegate(
            new[] { "record" }, policy: new RecordPolicyHook());
        try
        {
            childLimit.Delegate(new[] { "record" });
            throw new InvalidOperationException("delegation exceeded the child limit");
        }
        catch (DelegationException)
        {
            firstChild.Release();
        }
        childLimit.Delegate(new[] { "record" }).Release();

        var budgetRecord = new RecordTool();
        var budgetTools = new ToolRegistry();
        budgetTools.Register(budgetRecord);
        var budgetRoot = new Governor(
            RootAuthority(new[] { "record" }, new[] { "record" }, 1, 2, 1));
        var first = budgetRoot.Delegate(
            new[] { "record" }, policy: new RecordPolicyHook());
        var second = budgetRoot.Delegate(
            new[] { "record" }, policy: new RecordPolicyHook());
        first.Run(
            new FixtureModel("record", Args("first"), "first-done"),
            budgetTools,
            "record once");
        try
        {
            second.Run(
                new FixtureModel("record", Args("second"), "second-done"),
                budgetTools,
                "record twice");
            throw new InvalidOperationException("sibling budget was not enforced");
        }
        catch (PraxoException error)
        {
            Check(
                error.Code == "DELEGATION_BUDGET",
                $"unexpected budget error: {error.Code}");
            Check(budgetRecord.Calls == 1, "sibling budget produced extra effects");
        }
        finally
        {
            first.Release();
            second.Release();
        }

        var cancelRecord = new RecordTool();
        var cancelTools = new ToolRegistry();
        cancelTools.Register(cancelRecord);
        var cancelRoot = new Governor(
            RootAuthority(new[] { "record" }, new[] { "record" }, 1, 1, 1));
        var canceled = cancelRoot.Delegate(
            new[] { "record" }, policy: new RecordPolicyHook());
        using var source = new CancellationTokenSource();
        source.Cancel();
        try
        {
            canceled.Run(
                new FixtureModel("record", Args("safe"), "unexpected"),
                cancelTools,
                "record after cancel",
                source.Token);
            throw new InvalidOperationException("canceled child reported success");
        }
        catch (OperationCanceledException)
        {
            Check(cancelRecord.Calls == 0, "canceled child produced an effect");
        }
        finally
        {
            canceled.Release();
        }

        var editRecord = new RecordTool();
        var editTools = new ToolRegistry();
        editTools.Register(editRecord);
        var editRoot = new Governor(
            RootAuthority(new[] { "record" }, new[] { "record" }, 1, 1, 1));
        var edited = editRoot.Delegate(
            new[] { "record" }, policy: new RecordPolicyHook());
        try
        {
            edited.Run(
                new FixtureModel("record", Args("safe"), "unexpected"),
                editTools,
                "record safely",
                middleware: new IMiddleware[] { new EditMiddleware() });
            throw new InvalidOperationException(
                "edited child arguments were not reauthorized");
        }
        catch (PraxoException error)
        {
            Check(
                error.Code == "AGENT_POLICY_DENIED",
                $"unexpected policy error: {error.Code}");
            Check(editRecord.Calls == 0, "edited child arguments produced an effect");
        }
        finally
        {
            edited.Release();
        }

        Console.WriteLine("governance: delegation checks passed (6)");
        return 0;
    }

    private sealed class RecordPolicyHook : IPolicyHook
    {
        public Decision Authorize(PraxoAction action) => RecordPolicy(action);
    }

    private static JsonObject Args(string target)
        => new() { ["target"] = target };
}
