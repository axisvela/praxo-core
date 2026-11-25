defmodule PraxoOps.RemediationExecutor do
  @moduledoc false

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{executions: 0}, name: __MODULE__)
  end

  def execute(service) do
    GenServer.call(__MODULE__, {:execute, service}, 5_000)
  end

  def count do
    GenServer.call(__MODULE__, :count)
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, service}, _from, state) do
    state = %{state | executions: state.executions + 1}

    {:reply, {:ok, %{"service" => service, "status" => "executed"}}, state}
  end

  def handle_call(:count, _from, state) do
    {:reply, state.executions, state}
  end

  def handle_call(:reset, _from, state) do
    {:reply, :ok, %{state | executions: 0}}
  end
end
