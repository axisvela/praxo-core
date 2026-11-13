using System.Collections.Concurrent;

namespace Praxo.Core.Delegation;

public sealed class SubagentManager
{
    private readonly SubagentRunner _runner;
    private readonly ConcurrentDictionary<string, TaskState> _tasks = new();
    private int _sequence;

    public SubagentManager(SubagentRunner runner)
    {
        _runner = runner;
    }

    public SubagentTask Launch(SubagentRequest request)
    {
        if (_runner == null)
        {
            throw new InvalidOperationException("agent: subagent runner is required");
        }
        if (request == null
            || string.IsNullOrEmpty(request.ParentSessionId)
            || string.IsNullOrEmpty(request.AgentId))
        {
            throw new ArgumentException(
                "agent: subagent parent session and agent id are required");
        }
        var id = $"subagent-{Interlocked.Increment(ref _sequence)}";
        var now = DateTimeOffset.UtcNow;
        var task = new SubagentTask
        {
            Id = id,
            ParentSessionId = request.ParentSessionId,
            AgentId = request.AgentId,
            Mode = request.Mode,
            Status = SubagentStatus.Queued,
            CreatedAt = now,
            UpdatedAt = now,
        };
        var state = new TaskState(task);
        _tasks[id] = state;
        _ = Task.Run(() => ExecuteAsync(request, state));
        return Clone(state);
    }

    public SubagentTask? Check(string taskId)
        => _tasks.TryGetValue(taskId, out var state) ? Clone(state) : null;

    public async Task<SubagentTask> WaitAsync(
        string taskId,
        TimeSpan? timeout = null)
    {
        var state = Require(taskId);
        if (!state.Task.Status.Terminal())
        {
            var wait = timeout ?? Timeout.InfiniteTimeSpan;
            await state.Done.Task.WaitAsync(wait).ConfigureAwait(false);
        }
        return Clone(state);
    }

    public async Task UpdateAsync(string taskId, string prompt)
    {
        if (_runner is not ControllableRunner controllable)
        {
            throw new InvalidOperationException(
                "agent: subagent update unsupported");
        }
        var state = Require(taskId);
        lock (state)
        {
            if (state.Task.Status != SubagentStatus.Running)
            {
                throw new InvalidOperationException(
                    $"agent: subagent task \"{taskId}\" is not running");
            }
        }
        await controllable.UpdateAsync(taskId, prompt).ConfigureAwait(false);
    }

    public void Cancel(string taskId)
    {
        var state = Require(taskId);
        lock (state)
        {
            if (state.Task.Status.Terminal())
            {
                return;
            }
            state.Task.Status = SubagentStatus.Canceled;
            state.Task.UpdatedAt = DateTimeOffset.UtcNow;
            state.Done.TrySetResult(true);
        }
    }

    private async Task ExecuteAsync(SubagentRequest request, TaskState state)
    {
        SetTask(state, SubagentStatus.Running, "", "");
        try
        {
            var result = await _runner.RunAsync(request).ConfigureAwait(false);
            SetTask(state, SubagentStatus.Completed, result.Output, "");
        }
        catch (Exception error)
        {
            SetTask(state, SubagentStatus.Failed, "", error.Message);
        }
        finally
        {
            state.Done.TrySetResult(true);
        }
    }

    private static void SetTask(
        TaskState state,
        SubagentStatus status,
        string output,
        string error)
    {
        lock (state)
        {
            if (state.Task.Status.Terminal())
            {
                return;
            }
            state.Task.Status = status;
            state.Task.Output = output;
            state.Task.Error = error;
            state.Task.UpdatedAt = DateTimeOffset.UtcNow;
        }
    }

    private TaskState Require(string taskId)
        => _tasks.TryGetValue(taskId, out var state)
            ? state
            : throw new ArgumentException(
                $"agent: unknown subagent task \"{taskId}\"");

    private static SubagentTask Clone(TaskState state)
    {
        lock (state)
        {
            return new SubagentTask
            {
                Id = state.Task.Id,
                ParentSessionId = state.Task.ParentSessionId,
                AgentId = state.Task.AgentId,
                Mode = state.Task.Mode,
                Status = state.Task.Status,
                Output = state.Task.Output,
                Error = state.Task.Error,
                CreatedAt = state.Task.CreatedAt,
                UpdatedAt = state.Task.UpdatedAt,
            };
        }
    }

    private sealed class TaskState
    {
        public TaskState(SubagentTask task)
        {
            Task = task;
        }

        public SubagentTask Task { get; }

        public TaskCompletionSource<bool> Done { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);
    }
}
