defmodule Praxo.SubagentRequest do
  defstruct parent_session_id: "", agent_id: "", prompt: "",
            context: %{}, mode: "isolated", history: []
end

defmodule Praxo.SubagentResult do
  defstruct task_id: "", agent_id: "", output: "", usage: nil
end

defmodule Praxo.SubagentTask do
  defstruct id: "", parent_session_id: "", agent_id: "", mode: "isolated",
            status: "queued", output: "", error: "",
            created_at: nil, updated_at: nil
end

defmodule Praxo.SubagentManager do
  @terminal ["completed", "failed", "canceled"]

  defstruct run: nil, update: nil, state: nil

  def new(run, update \\ nil) when is_function(run, 1) do
    {:ok, state} = Agent.start_link(fn -> %{tasks: %{}, sequence: 0} end)
    %__MODULE__{run: run, update: update, state: state}
  end

  def launch(%__MODULE__{state: state} = manager, %Praxo.SubagentRequest{} = request) do
    if request.parent_session_id == "" or request.agent_id == "" do
      raise Praxo.Error,
        code: "SUBAGENT_INVALID",
        message: "agent: subagent parent session and agent id are required"
    end

    {id, task} =
      Agent.get_and_update(state, fn current ->
        sequence = current.sequence + 1
        id = "subagent-#{sequence}"
        now = timestamp()

        task = %Praxo.SubagentTask{
          id: id,
          parent_session_id: request.parent_session_id,
          agent_id: request.agent_id,
          mode: if(request.mode == "fork", do: "fork", else: "isolated"),
          status: "queued",
          created_at: now,
          updated_at: now
        }

        {{id, task}, %{current | sequence: sequence, tasks: Map.put(current.tasks, id, %{task: task, pid: nil})}}
      end)

    pid = spawn(fn ->
      receive do
        :start -> execute(manager, id, request)
      end
    end)

    Agent.update(state, fn current ->
      update_in(current.tasks[id], fn entry -> %{entry | pid: pid} end)
    end)
    send(pid, :start)
    task
  end

  def check(%__MODULE__{state: state}, task_id) do
    Agent.get(state, fn current ->
      case Map.get(current.tasks, task_id) do
        nil -> nil
        entry -> entry.task
      end
    end)
  end

  def wait(%__MODULE__{state: state} = manager, task_id, timeout \\ nil) do
    deadline = if timeout == nil, do: nil, else: System.monotonic_time(:millisecond) + timeout
    do_wait(manager, state, task_id, deadline)
  end

  def update(%__MODULE__{state: state, update: update} = _manager, task_id, prompt) do
    if update == nil do
      raise Praxo.Error,
        code: "SUBAGENT_UPDATE_UNSUPPORTED",
        message: "agent: subagent update unsupported"
    end

    task = check(%__MODULE__{state: state}, task_id)
    cond do
      task == nil ->
        raise Praxo.Error, code: "SUBAGENT_NOT_FOUND",
          message: "agent: unknown subagent task \"#{task_id}\""
      task.status != "running" ->
        raise Praxo.Error, code: "SUBAGENT_NOT_RUNNING",
          message: "agent: subagent task \"#{task_id}\" is not running"
      true ->
        update.(task_id, prompt)
    end
  end

  def cancel(%__MODULE__{state: state}, task_id) do
    entry = Agent.get(state, fn current -> Map.get(current.tasks, task_id) end)
    if entry == nil do
      raise Praxo.Error, code: "SUBAGENT_NOT_FOUND",
        message: "agent: unknown subagent task \"#{task_id}\""
    end

    if entry.task.status not in @terminal do
      if is_pid(entry.pid), do: Process.exit(entry.pid, :kill)
      set(state, task_id, "canceled")
    end
  end

  defp do_wait(manager, state, task_id, deadline) do
    task = check(%__MODULE__{state: state}, task_id)
    cond do
      task == nil ->
        raise Praxo.Error, code: "SUBAGENT_NOT_FOUND",
          message: "agent: unknown subagent task \"#{task_id}\""
      task.status in @terminal ->
        task
      deadline != nil and System.monotonic_time(:millisecond) >= deadline ->
        raise Praxo.Error, code: "SUBAGENT_TIMEOUT",
          message: "agent: subagent wait timed out"
      true ->
        Process.sleep(10)
        do_wait(manager, state, task_id, deadline)
    end
  end

  defp execute(manager, task_id, request) do
    set(manager.state, task_id, "running")

    try do
      result = manager.run.(request)
      set(manager.state, task_id, "completed", output: result.output)
    rescue
      error ->
        set(manager.state, task_id, "failed", error: Exception.message(error))
    end
  end

  defp set(state, task_id, status, opts \\ []) do
    Agent.update(state, fn current ->
      entry = Map.get(current.tasks, task_id)

      if entry == nil or entry.task.status in @terminal do
        current
      else
        task = %{
          entry.task
          | status: status,
            output: Keyword.get(opts, :output, ""),
            error: Keyword.get(opts, :error, ""),
            updated_at: timestamp()
        }

        %{current | tasks: Map.put(current.tasks, task_id, %{entry | task: task})}
      end
    end)
  end

  defp timestamp, do: DateTime.utc_now() |> DateTime.to_iso8601()
end
