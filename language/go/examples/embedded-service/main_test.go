package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type fakeModel struct{}

func (fakeModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{
		Message: model.Message{
			Role:    model.RoleAssistant,
			Content: "hello from the service",
		},
	}, nil
}

func TestRunRequiresPrincipal(t *testing.T) {
	agentInstance, err := newAgent(fakeModel{})
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, "/run", strings.NewReader(`{"prompt":"hi"}`))
	response := httptest.NewRecorder()
	newHandler(agentInstance, "local").ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", response.Code)
	}
}

func TestRunReturnsOutput(t *testing.T) {
	agentInstance, err := newAgent(fakeModel{})
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, "/run", strings.NewReader(`{"prompt":"hi"}`))
	request.Header.Set("X-Praxo-Principal", "user-1")
	response := httptest.NewRecorder()
	newHandler(agentInstance, "local").ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", response.Code, response.Body.String())
	}
	var body runResponse
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Output != "hello from the service" {
		t.Fatalf("unexpected output: %q", body.Output)
	}
}

func TestHealthz(t *testing.T) {
	agentInstance, err := newAgent(fakeModel{})
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()
	newHandler(agentInstance, "local").ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", response.Code)
	}
}
