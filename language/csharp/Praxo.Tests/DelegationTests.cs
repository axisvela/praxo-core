using Praxo.Core.Delegation;

namespace Praxo.Tests;

internal static class DelegationTests
{
    public static int Run()
    {
        var manager = new SubagentManager(new ImmediateRunner());
        var task = manager.Launch(Request());
        Check(task.ParentSessionId == "parent", "delegation parent");
        Check(task.AgentId == "child", "delegation agent");
        Check(task.Mode == SubagentMode.Fork, "delegation mode");
        var completed = manager.WaitAsync(task.Id, TimeSpan.FromSeconds(2))
            .GetAwaiter().GetResult();
        Check(completed.Status == SubagentStatus.Completed, "delegation completed");
        Check(completed.Output == "done", "delegation output");

        var failing = new SubagentManager(new FailingRunner());
        var failed = failing.WaitAsync(
            failing.Launch(Request()).Id,
            TimeSpan.FromSeconds(2)).GetAwaiter().GetResult();
        Check(failed.Status == SubagentStatus.Failed, "delegation failed");
        Check(failed.Error.Contains("boom"), "delegation failure detail");

        var gate = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var blocking = new SubagentManager(new BlockingRunner(gate));
        var running = blocking.Launch(Request());
        AwaitStatus(blocking, running.Id, SubagentStatus.Running);
        blocking.Cancel(running.Id);
        var canceled = blocking.WaitAsync(
            running.Id,
            TimeSpan.FromSeconds(2)).GetAwaiter().GetResult();
        Check(canceled.Status == SubagentStatus.Canceled, "delegation canceled");
        gate.TrySetResult(true);

        var updates = new List<string>();
        var updateGate = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var controllable = new SubagentManager(
            new ControllableTestRunner(updateGate, updates));
        var controlled = controllable.Launch(Request());
        AwaitStatus(controllable, controlled.Id, SubagentStatus.Running);
        controllable.UpdateAsync(controlled.Id, "steer").GetAwaiter().GetResult();
        Check(
            updates.SequenceEqual(new[] { controlled.Id + ":steer" }),
            "delegation update");
        updateGate.TrySetResult(true);
        var updated = controllable.WaitAsync(
            controlled.Id,
            TimeSpan.FromSeconds(2)).GetAwaiter().GetResult();
        Check(updated.Status == SubagentStatus.Completed, "delegation updated");

        try
        {
            controllable.UpdateAsync("missing", "steer").GetAwaiter().GetResult();
            throw new InvalidOperationException("expected unknown task");
        }
        catch (ArgumentException)
        {
        }
        return 1;
    }

    private static SubagentRequest Request()
        => new()
        {
            ParentSessionId = "parent",
            AgentId = "child",
            Prompt = "do work",
            Mode = SubagentMode.Fork,
        };

    private static void AwaitStatus(
        SubagentManager manager,
        string taskId,
        SubagentStatus status)
    {
        for (var attempt = 0; attempt < 100; attempt++)
        {
            if (manager.Check(taskId)?.Status == status)
            {
                return;
            }
            Thread.Sleep(10);
        }
        throw new InvalidOperationException($"status did not become {status}");
    }

    private static void Check(bool condition, string detail)
    {
        if (!condition)
        {
            throw new InvalidOperationException(detail);
        }
    }

    private sealed class ImmediateRunner : SubagentRunner
    {
        public Task<SubagentResult> RunAsync(SubagentRequest request)
            => Task.FromResult(new SubagentResult { Output = "done" });
    }

    private sealed class FailingRunner : SubagentRunner
    {
        public Task<SubagentResult> RunAsync(SubagentRequest request)
            => Task.FromException<SubagentResult>(
                new InvalidOperationException("boom"));
    }

    private sealed class BlockingRunner : SubagentRunner
    {
        private readonly TaskCompletionSource<bool> _gate;

        public BlockingRunner(TaskCompletionSource<bool> gate)
        {
            _gate = gate;
        }

        public async Task<SubagentResult> RunAsync(SubagentRequest request)
        {
            await _gate.Task.ConfigureAwait(false);
            return new SubagentResult { Output = "released" };
        }
    }

    private sealed class ControllableTestRunner : ControllableRunner
    {
        private readonly TaskCompletionSource<bool> _gate;
        private readonly List<string> _updates;

        public ControllableTestRunner(
            TaskCompletionSource<bool> gate,
            List<string> updates)
        {
            _gate = gate;
            _updates = updates;
        }

        public async Task<SubagentResult> RunAsync(SubagentRequest request)
        {
            await _gate.Task.ConfigureAwait(false);
            return new SubagentResult { Output = "released" };
        }

        public Task UpdateAsync(string taskId, string prompt)
        {
            _updates.Add(taskId + ":" + prompt);
            return Task.CompletedTask;
        }
    }
}
