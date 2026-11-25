defmodule PraxoOps.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PraxoOps.TelemetryStore,
      PraxoOps.RemediationExecutor,
      {Task.Supervisor, name: PraxoOps.TaskSupervisor}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: PraxoOps.Supervisor
    )
  end
end
