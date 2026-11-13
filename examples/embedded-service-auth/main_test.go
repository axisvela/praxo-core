package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

const testSecret = "test-secret"

type fakeModel struct{}

func (fakeModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{
		Message: model.Message{
			Role:    model.RoleAssistant,
			Content: "hello from the authenticated service",
		},
	}, nil
}

func testHandler(t *testing.T) (http.Handler, *fileStore) {
	t.Helper()
	store, err := newFileStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	agentInstance, err := newAgent(fakeModel{}, map[string]bool{"local": true}, store)
	if err != nil {
		t.Fatal(err)
	}
	return newHandler(agentInstance, testSecret, map[string]bool{"local": true}), store
}

func newRunRequest(token string) *http.Request {
	request := httptest.NewRequest(http.MethodPost, "/run", strings.NewReader(`{"prompt":"hi"}`))
	request.Header.Set("Content-Type", "application/json")
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	return request
}

func TestRequiresBearerToken(t *testing.T) {
	handler, _ := testHandler(t)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(""))
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", response.Code)
	}
}

func TestRejectsExpiredToken(t *testing.T) {
	token := signToken(testSecret, "user-1", "local", time.Now().Add(-time.Minute))
	handler, _ := testHandler(t)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(token))
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", response.Code)
	}
}

func TestRejectsUnknownTenant(t *testing.T) {
	token := signToken(testSecret, "user-1", "other", time.Now().Add(time.Hour))
	handler, _ := testHandler(t)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(token))
	if response.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", response.Code)
	}
}

func TestReturnsOutputForVerifiedTenant(t *testing.T) {
	token := signToken(testSecret, "user-1", "local", time.Now().Add(time.Hour))
	handler, store := testHandler(t)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(token))
	if response.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", response.Code, response.Body.String())
	}
	var body runResponse
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Output != "hello from the authenticated service" {
		t.Fatalf("unexpected output: %q", body.Output)
	}
	loaded, err := store.Load(context.Background(), "local/user-1")
	if err != nil {
		t.Fatal(err)
	}
	if loaded == nil || loaded.Status != "completed" || len(loaded.Messages) != 1 {
		t.Fatalf("checkpoint was not persisted: %#v", loaded)
	}
}
