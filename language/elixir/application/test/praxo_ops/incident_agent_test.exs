defmodule PraxoOps.IncidentAgentTest do
  use ExUnit.Case, async: false

  alias PraxoOps.{IncidentAgent, RemediationExecutor, TelemetryStore}

  setup do
    Application.put_env(:praxo_ops, :telemetry_failure, false)
    TelemetryStore.reset()
    RemediationExecutor.reset()
    :ok
  end

  test "AI-native operations copilot drafts review-only remediation" do
    assert {:ok, report, stats} =
             IncidentAgent.run("acme", "service-100", "Investigate the checkout incident.")

    assert report["service"] == "service-100"
    assert report["signals"]["suspect"] == "checkout-api"
    assert report["remediation"]["status"] == "draft_only"
    assert report["remediation"]["review_required"] == true

    assert report["remediation"]["diagnosis"] ==
             "checkout-api shows elevated error rate and latency"

    assert report["remediation"]["rationale"] =~
             "error_rate 0.18 and latency_ms 940 exceed the review threshold"

    assert report["model"] == "deterministic"
    assert is_list(report["agent_trace"])

    assert Enum.any?(report["agent_trace"], fn step ->
             Enum.any?(step["tool_calls"], &(&1["name"] == "search_signals"))
           end)

    assert Enum.any?(report["agent_trace"], fn step ->
             Enum.any?(step["tool_calls"], &(&1["name"] == "draft_remediation"))
           end)

    assert report["executions"] == 0
    assert stats == %{reads: 1, drafts: 1, executions: 0}
    assert RemediationExecutor.count() == 0
  end

  test "direct remediation intent is denied before any effect" do
    assert {:error, "AGENT_POLICY_DENIED", stats} =
             IncidentAgent.run("acme", "service-100", "Remediate now for service-100.")

    assert stats == %{reads: 0, drafts: 0, executions: 0}
    assert RemediationExecutor.count() == 0
  end

  test "out-of-scope service is denied before telemetry read" do
    assert {:error, "AGENT_POLICY_DENIED", stats} =
             IncidentAgent.run("acme", "service-200", "Investigate the checkout incident.")

    assert stats == %{reads: 0, drafts: 0, executions: 0}
    assert TelemetryStore.reads() == 0
  end

  test "mismatched tenant is denied before telemetry read" do
    assert {:error, "AGENT_POLICY_DENIED", stats} =
             IncidentAgent.run("other", "service-100", "Investigate the checkout incident.")

    assert stats == %{reads: 0, drafts: 0, executions: 0}
    assert TelemetryStore.reads() == 0
  end

  test "telemetry dependency failure returns after one read without draft" do
    Application.put_env(:praxo_ops, :telemetry_failure, true)

    assert {:error, "TELEMETRY_UNAVAILABLE", stats} =
             IncidentAgent.run("acme", "service-100", "Investigate the checkout incident.")

    assert stats == %{reads: 1, drafts: 0, executions: 0}
    assert RemediationExecutor.count() == 0
  end
end
