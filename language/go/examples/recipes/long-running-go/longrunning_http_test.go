package longrunning

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func postJSON(t *testing.T, client *http.Client, url string, value any, failAfterCommit bool) (int, []byte) {
	t.Helper()
	return postJSONToken(t, client, url, "", value, failAfterCommit)
}

func postJSONToken(t *testing.T, client *http.Client, url, token string, value any, failAfterCommit bool) (int, []byte) {
	t.Helper()
	body, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	request, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Content-Type", "application/json")
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	if failAfterCommit {
		request.Header.Set("X-Fail-After-Commit", "1")
	}
	response, err := client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	data, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	return response.StatusCode, data
}

func getOperation(t *testing.T, client *http.Client, url string) remoteOperation {
	t.Helper()
	response, err := client.Get(url)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("status=%d", response.StatusCode)
	}
	var op remoteOperation
	if err := json.NewDecoder(response.Body).Decode(&op); err != nil {
		t.Fatal(err)
	}
	return op
}

func TestLongRunningHTTPResponseLossAndRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	service := newRemoteOperationsAt(path)
	server := httptest.NewServer(longRunningHandler(service))
	client := server.Client()
	client.Timeout = 5 * time.Second

	status, _ := postJSON(t, client, server.URL+"/operations", map[string]any{"key": "key-1"}, true)
	if status != http.StatusInternalServerError {
		t.Fatalf("simulated loss status=%d", status)
	}
	if service.effectCount() != 1 {
		t.Fatalf("effects=%d", service.effectCount())
	}

	status, body := postJSON(t, client, server.URL+"/operations", map[string]any{"key": "key-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("retry status=%d body=%s", status, body)
	}
	var submitted struct {
		ID      string `json:"id"`
		Created bool   `json:"created"`
	}
	if err := json.Unmarshal(body, &submitted); err != nil {
		t.Fatal(err)
	}
	if submitted.Created || submitted.ID == "" {
		t.Fatalf("submitted=%#v", submitted)
	}
	server.Close()

	restarted := newRemoteOperationsAt(path)
	server = httptest.NewServer(longRunningHandler(restarted))
	defer server.Close()
	client = server.Client()
	client.Timeout = 5 * time.Second
	op := getOperation(t, client, server.URL+"/operations/"+submitted.ID)
	if op.State != remoteAccepted {
		t.Fatalf("state after restart=%s", op.State)
	}
	status, body = postJSON(t, client, server.URL+"/operations", map[string]any{"key": "key-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("recover status=%d body=%s", status, body)
	}
	if err := json.Unmarshal(body, &submitted); err != nil {
		t.Fatal(err)
	}
	if submitted.Created || restarted.effectCount() != 1 {
		t.Fatalf("submitted=%#v effects=%d", submitted, restarted.effectCount())
	}
}

func TestLongRunningNewHandlerRequiresBearer(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	server := httptest.NewServer(NewHandler(path, "secret", "verifier-secret"))
	defer server.Close()
	client := server.Client()
	client.Timeout = 5 * time.Second

	status, _ := postJSON(t, client, server.URL+"/operations", map[string]any{"key": "key-1"}, false)
	if status != http.StatusUnauthorized {
		t.Fatalf("unauthenticated status=%d", status)
	}
	status, body := postJSONToken(t, client, server.URL+"/operations", "secret", map[string]any{"key": "key-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("authenticated status=%d body=%s", status, body)
	}
}

func TestLongRunningHTTPRequiresBearerToken(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	service := newRemoteOperationsAt(path)
	server := httptest.NewTLSServer(requireBearer(longRunningHandler(service), "secret"))
	defer server.Close()
	client := server.Client()
	client.Timeout = 5 * time.Second

	status, _ := postJSON(t, client, server.URL+"/operations", map[string]any{"key": "key-1"}, false)
	if status != http.StatusUnauthorized {
		t.Fatalf("unauthenticated status=%d", status)
	}
	if service.effectCount() != 0 {
		t.Fatalf("unauthenticated request produced effects=%d", service.effectCount())
	}
	status, _ = postJSONToken(t, client, server.URL+"/operations", "wrong", map[string]any{"key": "key-1"}, false)
	if status != http.StatusUnauthorized || service.effectCount() != 0 {
		t.Fatalf("wrong token status=%d effects=%d", status, service.effectCount())
	}
	status, body := postJSONToken(t, client, server.URL+"/operations", "secret", map[string]any{"key": "key-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("authenticated status=%d body=%s", status, body)
	}
	if service.effectCount() != 1 {
		t.Fatalf("effects=%d", service.effectCount())
	}
}

func TestLongRunningHTTPCancelAndEffectEvidence(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	verifier := newEffectVerifier("http-secret")
	service := newRemoteOperationsWithVerifier(path, verifier)
	server := httptest.NewServer(longRunningHandler(service))
	defer server.Close()
	client := server.Client()
	client.Timeout = 5 * time.Second

	status, body := postJSON(t, client, server.URL+"/operations", map[string]any{"key": "cancel-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("submit status=%d body=%s", status, body)
	}
	var submitted struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(body, &submitted); err != nil {
		t.Fatal(err)
	}
	status, body = postJSON(t, client, server.URL+"/operations/"+submitted.ID+"/cancel-request", map[string]any{}, false)
	if status != http.StatusOK || !strings.Contains(string(body), "cancel_requested") {
		t.Fatalf("cancel request status=%d body=%s", status, body)
	}
	status, body = postJSON(t, client, server.URL+"/operations/"+submitted.ID+"/cancel-confirm", map[string]any{}, false)
	if status != http.StatusOK || !strings.Contains(string(body), "canceled") {
		t.Fatalf("cancel confirm status=%d body=%s", status, body)
	}

	status, body = postJSON(t, client, server.URL+"/operations", map[string]any{"key": "effect-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("submit status=%d body=%s", status, body)
	}
	if err := json.Unmarshal(body, &submitted); err != nil {
		t.Fatal(err)
	}
	status, body = postJSON(t, client, server.URL+"/operations/"+submitted.ID+"/complete", map[string]any{}, false)
	if status != http.StatusOK || !strings.Contains(string(body), "completed") {
		t.Fatalf("complete status=%d body=%s", status, body)
	}
	evidence := "room=kitchen;sensor=door"
	status, _ = postJSON(t, client, server.URL+"/operations/"+submitted.ID+"/verify-effect", map[string]any{"evidence": ""}, false)
	if status != http.StatusConflict {
		t.Fatalf("empty evidence status=%d", status)
	}
	status, _ = postJSON(t, client, server.URL+"/operations/"+submitted.ID+"/verify-effect", map[string]any{"evidence": evidence, "receipt": "forged"}, false)
	if status != http.StatusConflict {
		t.Fatalf("forged receipt status=%d", status)
	}
	status, body = postJSON(t, client, server.URL+"/operations/"+submitted.ID+"/verify-effect", map[string]any{"evidence": evidence, "receipt": verifier.sign(submitted.ID, evidence)}, false)
	if status != http.StatusOK || !strings.Contains(string(body), "effect_verified") {
		t.Fatalf("verify status=%d body=%s", status, body)
	}
}
