using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class AgentOptions
{
    public IModel Model { get; }

    public ToolRegistry? Tools { get; set; }

    public IEventSink? Events { get; set; }

    public IPolicyHook? Policy { get; set; }

    public string SystemPrompt { get; set; } = "";

    public List<string> MemoryFiles { get; set; } = new();

    public ContextBudget? Context { get; set; }

    public IContextCompactor? Compactor { get; set; }

    public List<IMiddleware> Middleware { get; set; } = new();

    public List<ModelMiddleware> ModelMiddleware { get; set; } = new();

    public StructuredOutput? StructuredOutput { get; set; }

    public List<string> AllowedTools { get; set; } = new();

    public IToolSelector? ToolSelector { get; set; }

    public PiiRedactor? PiiRedactor { get; set; }

    public int ModelCallLimit { get; set; }

    public int ToolCallLimit { get; set; }

    public IModel? FallbackModel { get; set; }

    public string? ToolChoice { get; set; }

    public ResponseFormat? ResponseFormat { get; set; }

    public int MaxSteps { get; set; } = 8;

    public int MaxParallelTools { get; set; }

    public CancellationToken CancellationToken { get; set; }

    public long MaxTokens { get; set; }

    public AgentOptions(IModel model)
    {
        Model = model;
    }
}

public sealed class Agent
{
    private readonly AgentOptions _options;
    private readonly string _systemPrompt;
    private readonly List<IMiddleware> _middleware;
    private readonly List<ModelMiddleware> _modelMiddleware;

    public Agent(AgentOptions options)
    {
        _options = options;
        var memory = LoadAgentsMd(options.MemoryFiles);
        _systemPrompt = string.IsNullOrEmpty(memory)
            ? options.SystemPrompt
            : $"{options.SystemPrompt}\n\n{memory}".Trim();
        var middleware = options.Middleware.ToList();
        if (options.StructuredOutput != null)
        {
            middleware.Add(options.StructuredOutput);
        }
        if (options.ToolSelector != null)
        {
            middleware.Add(new ToolSelectionMiddleware(options.ToolSelector));
        }
        if (options.PiiRedactor != null)
        {
            middleware.Add(new PiiMiddleware(options.PiiRedactor));
        }
        if (options.ModelCallLimit > 0 || options.ToolCallLimit > 0)
        {
            middleware.Add(new CallLimitMiddleware(options.ModelCallLimit, options.ToolCallLimit));
        }
        _middleware = MiddlewareChain.Merge(middleware);
        _modelMiddleware = options.ModelMiddleware.ToList();
        if (options.FallbackModel != null)
        {
            _modelMiddleware.Add(ModelFallback.Fallback(options.FallbackModel));
        }
    }

    public RunResult Run(Session session, string prompt)
        => RunInternal(session, prompt, null);

    public RunResult RunStream(
        Session session,
        string prompt,
        Action<string> onDelta)
        => RunInternal(session, prompt, onDelta);

    private RunResult RunInternal(
        Session session,
        string prompt,
        Action<string>? onDelta)
    {
        ThrowIfCancelled();
        var maxSteps = _options.MaxSteps > 0 ? _options.MaxSteps : 8;
        var runId = $"run-{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        var messages = session.Messages.Select(Clone).ToList();
        if (!string.IsNullOrEmpty(_systemPrompt))
        {
            messages.Insert(0, Message.Text(Roles.System, _systemPrompt));
        }
        messages.Add(Message.Text(Roles.User, prompt));
        var usage = new Usage();

        var entered = new List<IMiddleware>();
        try
        {
            BeforeRun(runId, prompt, entered);
        }
        catch (Exception startupError)
        {
            AfterRun(entered, null, AsPraxoException(startupError));
            throw;
        }
        Emit("run.started", session.Id, runId, null);
        var afterRunInvoked = false;
        try
        {
            for (var step = 1; step <= maxSteps; step++)
            {
                ThrowIfCancelled();
                Authorize(new Action
                {
                    Kind = "model.generate",
                    SessionId = session.Id,
                });
                messages = Compact(messages);
                var request = new Request
                {
                    Messages = messages,
                    Tools = ToolSpecs(),
                    ToolChoice = _options.ToolChoice,
                    ResponseFormat = _options.ResponseFormat,
                };
                var call = new ModelCall
                {
                    RunId = runId,
                    SessionId = session.Id,
                    Request = request,
                };
                BeforeModel(call);
                Response response;
                if (call.Skip)
                {
                    response = call.Response ?? throw new PraxoException(
                        "AGENT_MIDDLEWARE", "agent: model middleware skipped without a response");
                }
                else if (onDelta != null)
                {
                    var streaming = _options.Model as IStreamingModel
                        ?? throw new PraxoException(
                            "AGENT_STREAM", "agent: model does not support streaming");
                    response = streaming.GenerateStream(call.Request, onDelta);
                }
                else
                {
                    response = Generate(call.Request);
                }
                ThrowIfCancelled();
                AfterModel(call, response);
                usage = usage.Plus(response.Usage);
                if (_options.MaxTokens > 0
                    && usage.InputTokens + usage.OutputTokens > _options.MaxTokens)
                {
                    throw PraxoException.MaxTokens();
                }
                messages.Add(response.Message);
                if (response.Message.ToolCalls.Count == 0)
                {
                    var result = new RunResult
                    {
                        RunId = runId,
                        Output = response.Message.Content ?? "",
                        Steps = step,
                        Usage = usage,
                    };
                    afterRunInvoked = true;
                    var cleanupError = AfterRun(entered, result, null);
                    if (cleanupError != null)
                    {
                        throw cleanupError;
                    }
                    Emit("run.completed", session.Id, runId, null);
                    return result;
                }
                messages.AddRange(InvokeTools(
                    response.Message.ToolCalls, runId, session.Id));
            }
            throw PraxoException.MaxSteps();
        }
        catch (Exception error)
        {
            if (!afterRunInvoked)
            {
                AfterRun(entered, null, AsPraxoException(error));
            }
            Emit("run.failed", session.Id, runId, new JsonObject
            {
                ["error"] = error.Message,
            });
            throw;
        }
    }

    private List<Message> Compact(IReadOnlyList<Message> messages)
    {
        if (_options.Context == null || _options.Context.MaxTokens == 0)
        {
            return messages.Select(Clone).ToList();
        }
        var current = messages.Select(Clone).ToList();
        if (_options.Compactor != null
            && ContextEstimator.EstimateTokens(current) > _options.Context.MaxTokens)
        {
            current = _options.Compactor.Compact(current, _options.Context);
        }
        var (output, ok) = _options.Context.Compact(current);
        if (!ok)
        {
            throw PraxoException.ContextBudget();
        }
        return output;
    }

    private List<ToolSpec> ToolSpecs()
    {
        if (_options.Tools == null)
        {
            return new List<ToolSpec>();
        }
        var specs = _options.Tools.Specs();
        if (_options.AllowedTools.Count == 0)
        {
            return specs.ToList();
        }
        return specs.Where(spec => _options.AllowedTools.Contains(spec.Name)).ToList();
    }

    private bool ToolAllowed(string name)
        => _options.AllowedTools.Count == 0 || _options.AllowedTools.Contains(name);

    private Response Generate(Request request)
    {
        ModelHandler handler = _options.Model.Generate;
        foreach (var middleware in _modelMiddleware.AsEnumerable().Reverse())
        {
            handler = middleware(handler);
        }
        return handler(request);
    }

    private List<Message> InvokeTools(
        IReadOnlyList<ToolCall> calls,
        string runId,
        string sessionId)
    {
        if (_options.MaxParallelTools <= 1 || calls.Count <= 1)
        {
            return calls
                .Select(call => InvokeTool(call, runId, sessionId))
                .ToList();
        }
        var prepared = calls
            .Select(call => PrepareTool(call, runId, sessionId))
            .ToList();
        var results = new ToolResult[prepared.Count];
        using var permits = new SemaphoreSlim(
            Math.Min(_options.MaxParallelTools, prepared.Count));
        var tasks = prepared
            .Select((item, index) => Task.Run(() =>
            {
                permits.Wait();
                try
                {
                    results[index] = ExecutePrepared(item);
                }
                finally
                {
                    permits.Release();
                }
            }))
            .ToArray();
        Task.WaitAll(tasks);
        var messages = new List<Message>();
        for (var index = 0; index < prepared.Count; index++)
        {
            messages.Add(FinishTool(prepared[index], results[index]));
        }
        return messages;
    }

    private Message InvokeTool(ToolCall call, string runId, string sessionId)
    {
        var prepared = PrepareTool(call, runId, sessionId);
        return FinishTool(prepared, ExecutePrepared(prepared));
    }

    private PreparedTool PrepareTool(ToolCall call, string runId, string sessionId)
    {
        ThrowIfCancelled();
        if (!ToolAllowed(call.Name))
        {
            throw new PraxoException(
                "AGENT_TOOL_NOT_ALLOWED", $"agent: tool {call.Name} is not allowed");
        }
        var originalName = call.Name;
        var originalArguments = call.Arguments.DeepClone();
        Authorize(new Action
        {
            Kind = "tool.invoke",
            SessionId = sessionId,
            ToolName = originalName,
            Arguments = (JsonObject)originalArguments.DeepClone(),
        });
        var middlewareCall = new MiddlewareToolCall
        {
            RunId = runId,
            SessionId = sessionId,
            Call = call,
        };
        BeforeTool(middlewareCall);
        var finalCall = middlewareCall.Call;
        if (!ToolAllowed(finalCall.Name))
        {
            throw new PraxoException(
                "AGENT_TOOL_NOT_ALLOWED", $"agent: tool {finalCall.Name} is not allowed");
        }
        var changed = finalCall.Name != originalName
            || Json.Stringify(finalCall.Arguments) != Json.Stringify(originalArguments);
        if (changed)
        {
            Authorize(new Action
            {
                Kind = "tool.invoke",
                SessionId = sessionId,
                ToolName = finalCall.Name,
                Arguments = (JsonObject)finalCall.Arguments.DeepClone(),
            });
        }
        if (middlewareCall.Skip)
        {
            return new PreparedTool
            {
                MiddlewareCall = middlewareCall,
                Active = finalCall,
                Skip = true,
                Value = middlewareCall.Result,
                Error = middlewareCall.Error,
            };
        }
        var tools = _options.Tools
            ?? throw PraxoException.ToolNotFound($"tool {finalCall.Name} is not registered");
        var tool = tools.Get(finalCall.Name);
        Emit("tool.call", sessionId, runId, new JsonObject
        {
            ["name"] = finalCall.Name,
            ["arguments"] = finalCall.Arguments.DeepClone(),
        });
        return new PreparedTool
        {
            MiddlewareCall = middlewareCall,
            Active = finalCall,
            Tool = tool,
        };
    }

    private ToolResult ExecutePrepared(PreparedTool prepared)
    {
        if (prepared.Skip)
        {
            return new ToolResult
            {
                Value = prepared.Value,
                Error = prepared.Error,
            };
        }
        ThrowIfCancelled();
        try
        {
            return new ToolResult
            {
                Value = prepared.Tool!.Invoke(prepared.Active.Arguments),
            };
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception caught)
        {
            return new ToolResult { Error = AsPraxoException(caught) };
        }
    }

    private Message FinishTool(PreparedTool prepared, ToolResult result)
    {
        AfterTool(prepared.MiddlewareCall, result);
        if (result.Error != null)
        {
            throw result.Error;
        }
        return Message.Tool(Json.Stringify(result.Value), prepared.Active.Id);
    }

    private void ThrowIfCancelled()
    {
        if (_options.CancellationToken.IsCancellationRequested)
        {
            throw new OperationCanceledException(_options.CancellationToken);
        }
    }

    private void Authorize(Action action)
    {
        if (_options.Policy == null)
        {
            return;
        }
        var decision = _options.Policy.Authorize(action);
        if (!decision.Allowed)
        {
            throw new PraxoException(
                "AGENT_POLICY_DENIED",
                $"agent: {action.Kind} denied: {decision.Reason}");
        }
    }

    private void BeforeRun(string runId, string prompt, List<IMiddleware> entered)
    {
        var state = new RunState { RunId = runId, Prompt = prompt };
        foreach (var middleware in _middleware)
        {
            entered.Add(middleware);
            middleware.BeforeRun(state);
        }
    }

    private static PraxoException AsPraxoException(Exception error)
        => error as PraxoException
            ?? new PraxoException("AGENT_MIDDLEWARE", error.Message);

    private void BeforeModel(ModelCall call)
    {
        foreach (var middleware in _middleware)
        {
            middleware.BeforeModel(call);
            if (call.Skip)
            {
                break;
            }
        }
    }

    private void AfterModel(ModelCall call, Response response)
    {
        foreach (var middleware in _middleware)
        {
            middleware.AfterModel(call, response);
        }
    }

    private void BeforeTool(MiddlewareToolCall call)
    {
        foreach (var middleware in _middleware)
        {
            middleware.BeforeTool(call);
            if (call.Skip)
            {
                break;
            }
        }
    }

    private void AfterTool(MiddlewareToolCall call, ToolResult result)
    {
        foreach (var middleware in _middleware)
        {
            middleware.AfterTool(call, result);
        }
    }

    private Exception? AfterRun(
        List<IMiddleware> entered,
        RunResult? result,
        PraxoException? error)
    {
        Exception? firstError = null;
        foreach (var middleware in entered)
        {
            try
            {
                middleware.AfterRun(result, error);
            }
            catch (Exception caught)
            {
                firstError ??= caught;
                if (error == null)
                {
                    error = AsPraxoException(caught);
                }
            }
        }
        return firstError;
    }

    private void Emit(string kind, string sessionId, string runId, JsonObject? data)
    {
        _options.Events?.Emit(new Event(kind, sessionId).WithRun(runId)
            .WithData(data ?? new JsonObject()));
    }

    private sealed class PreparedTool
    {
        public MiddlewareToolCall MiddlewareCall { get; init; } = new();

        public ToolCall Active { get; init; } = new();

        public ITool? Tool { get; init; }

        public bool Skip { get; init; }

        public JsonNode? Value { get; init; }

        public PraxoException? Error { get; init; }
    }

    private static Message Clone(Message message)
        => new()
        {
            Role = message.Role,
            Content = message.Content,
            ContentBlocks = message.ContentBlocks.Select(block => new ContentBlock
            {
                Type = block.Type,
                Text = block.Text,
                ImageUrl = block.ImageUrl,
                Data = block.Data,
            }).ToList(),
            ToolCalls = message.ToolCalls.Select(call => new ToolCall
            {
                Id = call.Id,
                Name = call.Name,
                Arguments = (JsonObject)call.Arguments.DeepClone(),
            }).ToList(),
            ToolId = message.ToolId,
        };

    private static string LoadAgentsMd(IEnumerable<string> paths)
    {
        const int maxBytes = 64 * 1024;
        var output = new StringBuilder();
        var used = 0;
        foreach (var path in paths)
        {
            if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
            {
                continue;
            }
            var text = File.ReadAllText(path).Trim();
            if (text.Length == 0)
            {
                continue;
            }
            var chunk = $"## AGENTS.md: {path}\n{text}";
            var bytes = Encoding.UTF8.GetByteCount(chunk);
            if (used + bytes > maxBytes)
            {
                break;
            }
            if (output.Length > 0)
            {
                output.Append("\n\n");
            }
            output.Append(chunk);
            used += bytes;
        }
        return output.ToString();
    }
}
