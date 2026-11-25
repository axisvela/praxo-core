defmodule PraxoOps.SupervisionTest do
  use ExUnit.Case, async: false

  alias PraxoOps.TelemetryStore

  setup do
    Application.put_env(:praxo_ops, :telemetry_failure, false)
    TelemetryStore.reset()
    :ok
  end

  test "supervisor restarts the telemetry process" do
    old_pid = Process.whereis(TelemetryStore)
    assert is_pid(old_pid)

    Process.exit(old_pid, :kill)
    new_pid = wait_for_restart(old_pid, 50)

    assert is_pid(new_pid)
    assert new_pid != old_pid
    assert {:ok, signal} = TelemetryStore.search("service-100")
    assert signal["suspect"] == "checkout-api"
  end

  defp wait_for_restart(_old_pid, 0), do: flunk("telemetry process did not restart")

  defp wait_for_restart(old_pid, attempts) do
    case Process.whereis(TelemetryStore) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _ ->
        Process.sleep(20)
        wait_for_restart(old_pid, attempts - 1)
    end
  end
end
