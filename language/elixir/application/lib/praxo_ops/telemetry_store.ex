defmodule PraxoOps.TelemetryStore do
  @moduledoc false

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{reads: 0}, name: __MODULE__)
  end

  def search(service) do
    GenServer.call(__MODULE__, {:search, service}, 5_000)
  end

  def reads do
    GenServer.call(__MODULE__, :reads)
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:search, service}, _from, state) do
    state = %{state | reads: state.reads + 1}

    if Application.get_env(:praxo_ops, :telemetry_failure, false) do
      {:reply, {:error, "TELEMETRY_UNAVAILABLE"}, state}
    else
      signal = %{
        "service" => service,
        "error_rate" => 0.18,
        "latency_ms" => 940,
        "suspect" => "checkout-api",
        "trace" => "trace-100",
        "source" => "telemetry_fixture"
      }

      {:reply, {:ok, signal}, state}
    end
  end

  def handle_call(:reads, _from, state) do
    {:reply, state.reads, state}
  end

  def handle_call(:reset, _from, state) do
    {:reply, :ok, %{state | reads: 0}}
  end
end
