package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type fakeModel struct{}

func (fakeModel) Generate(context.Context, model.Request) (model.Response, error) {
	return assistant("not-json", nil), nil
}

func testRunner(t *testing.T) *Runner {
	t.Helper()
	t.Setenv("PRAXO_BASE_URL", "")
	t.Setenv("PRAXO_MODEL", "")
	runner := NewRunner()
	runner.telemetry.reset()
	runner.telemetry.setFailure(false)
	runner.executor.reset()
	runner.setModel(nil)
	return runner
}

func postIncident(t *testing.T, handler http.Handler, tenant, body string) *httptest.ResponseRecorder {
	t.Helper()
	request := httptest.NewRequest(http.MethodPost, "/api/ops/incidents", strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	if tenant != "" {
		request.Header.Set("X-Tenant-Id", tenant)
	}
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	return recorder
}

func TestOpsSuccess(t *testing.T) {
	runner := testRunner(t)
	handler := newHandler(runner, serviceScope)

	response := postIncident(t, handler, tenantScope, `{"intent":"Investigate the checkout incident."}`)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}

	var payload struct {
		Report map[string]any `json:"report"`
		Agent  Stats          `json:"agent"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if payload.Report["model"] != "deterministic" {
		t.Fatalf("model = %v", payload.Report["model"])
	}
	remediation, ok := payload.Report["remediation"].(map[string]any)
	if !ok {
		t.Fatalf("remediation = %#v", payload.Report["remediation"])
	}
	if remediation["status"] != "draft_only" {
		t.Fatalf("status = %v", remediation["status"])
	}
	if remediation["diagnosis"] == "" || remediation["rationale"] == "" {
		t.Fatalf("missing model diagnosis/rationale: %#v", remediation)
	}
	if payload.Report["executions"].(float64) != 0 {
		t.Fatalf("executions = %v", payload.Report["executions"])
	}
	if payload.Agent != (Stats{Reads: 1, Drafts: 1, Executions: 0}) {
		t.Fatalf("stats = %+v", payload.Agent)
	}
	trace, ok := payload.Report["agent_trace"].([]any)
	if !ok || len(trace) < 3 {
		t.Fatalf("trace = %#v", payload.Report["agent_trace"])
	}
	if runner.telemetry.readsCount() != 1 || runner.executor.count() != 0 {
		t.Fatalf("reads=%d executions=%d", runner.telemetry.readsCount(), runner.executor.count())
	}
}

func TestTenantBoundaries(t *testing.T) {
	runner := testRunner(t)
	handler := newHandler(runner, serviceScope)

	missing := postIncident(t, handler, "", `{"intent":"Investigate."}`)
	if missing.Code != http.StatusUnauthorized {
		t.Fatalf("missing tenant status = %d", missing.Code)
	}

	mismatch := postIncident(t, handler, "other", `{"intent":"Investigate."}`)
	if mismatch.Code != http.StatusForbidden {
		t.Fatalf("mismatch status = %d", mismatch.Code)
	}
	if runner.telemetry.readsCount() != 0 {
		t.Fatalf("tenant boundary read telemetry %d times", runner.telemetry.readsCount())
	}
}

func TestDirectRemediationDenied(t *testing.T) {
	runner := testRunner(t)
	handler := newHandler(runner, serviceScope)

	response := postIncident(t, handler, tenantScope, `{"intent":"Remediate now for service-100."}`)
	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var payload map[string]any
	if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if payload["error"] != "AGENT_POLICY_DENIED" {
		t.Fatalf("error = %v", payload["error"])
	}
	if runner.executor.count() != 0 {
		t.Fatalf("executor count = %d", runner.executor.count())
	}
}

func TestServiceOutOfScope(t *testing.T) {
	runner := testRunner(t)
	_, stats, _, err := runner.Run(context.Background(), tenantScope, "service-200", "Investigate.")
	var runErr *RunError
	if !errors.As(err, &runErr) || runErr.Code != "AGENT_POLICY_DENIED" {
		t.Fatalf("err = %v", err)
	}
	if stats != (Stats{}) || runner.telemetry.readsCount() != 0 {
		t.Fatalf("stats=%+v reads=%d", stats, runner.telemetry.readsCount())
	}
}

func TestTelemetryFailure(t *testing.T) {
	runner := testRunner(t)
	runner.telemetry.setFailure(true)
	handler := newHandler(runner, serviceScope)

	response := postIncident(t, handler, tenantScope, `{"intent":"Investigate."}`)
	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var payload map[string]any
	if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if payload["error"] != "TOOL_ERROR" {
		t.Fatalf("error = %v", payload["error"])
	}
}

func TestValidation(t *testing.T) {
	runner := testRunner(t)
	handler := newHandler(runner, serviceScope)
	response := postIncident(t, handler, tenantScope, `{}`)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d", response.Code)
	}
}

func TestInvalidModelOutput(t *testing.T) {
	runner := testRunner(t)
	runner.setModel(fakeModel{})
	_, stats, trace, err := runner.Run(context.Background(), tenantScope, serviceScope, "Investigate.")
	var runErr *RunError
	if !errors.As(err, &runErr) || runErr.Code != "AGENT_INVALID_OUTPUT" {
		t.Fatalf("err = %v", err)
	}
	if stats != (Stats{}) || len(trace) != 1 {
		t.Fatalf("stats=%+v trace=%d", stats, len(trace))
	}
}

func TestTraceRecordsModelTools(t *testing.T) {
	runner := testRunner(t)
	report, _, trace, err := runner.Run(context.Background(), tenantScope, serviceScope, "Investigate.")
	if err != nil {
		t.Fatal(err)
	}
	if report["model"] != "deterministic" {
		t.Fatalf("model = %v", report["model"])
	}
	if !traceHasTool(trace, "search_signals") || !traceHasTool(trace, "draft_remediation") {
		t.Fatalf("trace does not contain model-selected tools: %#v", trace)
	}
}

func traceHasTool(trace []TraceStep, name string) bool {
	for _, step := range trace {
		for _, call := range step.ToolCalls {
			if call["name"] == name {
				return true
			}
		}
		if calls, ok := step.ModelOutput["tool_calls"].([]map[string]any); ok {
			for _, call := range calls {
				if call["name"] == name {
					return true
				}
			}
		}
	}
	return false
}
