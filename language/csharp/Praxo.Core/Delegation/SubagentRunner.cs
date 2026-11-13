namespace Praxo.Core.Delegation;

public interface SubagentRunner
{
    Task<SubagentResult> RunAsync(SubagentRequest request);
}

public interface ControllableRunner : SubagentRunner
{
    Task UpdateAsync(string taskId, string prompt);
}
