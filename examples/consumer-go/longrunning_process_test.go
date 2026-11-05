package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type remoteEffectAuthority struct {
	url    string
	token  string
	client *http.Client
}

func (r *remoteEffectAuthority) valid(operationID, evidence, receipt string) bool {
	body, err := json.Marshal(map[string]any{
		"operation_id": operationID,
		"evidence":     evidence,
		"receipt":      receipt,
	})
	if err != nil {
		return false
	}
	request, err := http.NewRequest(http.MethodPost, r.url, bytes.NewReader(body))
	if err != nil {
		return false
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer "+r.token)
	response, err := r.client.Do(request)
	if err != nil {
		return false
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return false
	}
	var result struct {
		Valid bool `json:"valid"`
	}
	if err := json.NewDecoder(response.Body).Decode(&result); err != nil {
		return false
	}
	return result.Valid
}

func TestMain(m *testing.M) {
	if os.Getenv("PRAXO_VERIFIER_SERVER") == "1" {
		runLongRunningVerifierServer()
		return
	}
	if os.Getenv("PRAXO_LONG_RUNNING_SERVER") == "1" {
		runLongRunningServer()
		return
	}
	os.Exit(m.Run())
}

func runLongRunningVerifierServer() {
	secret := os.Getenv("PRAXO_VERIFIER_SECRET")
	token := os.Getenv("PRAXO_VERIFIER_TOKEN")
	if secret == "" || token == "" {
		fmt.Fprintln(os.Stderr, "missing PRAXO_VERIFIER_SECRET or PRAXO_VERIFIER_TOKEN")
		os.Exit(1)
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("LISTEN=%s\n", listener.Addr().String())
	verifier := newEffectVerifier(secret)
	handler := requireBearer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/verify" {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		var request struct {
			OperationID string `json:"operation_id"`
			Evidence    string `json:"evidence"`
			Receipt     string `json:"receipt"`
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			http.Error(w, "invalid request", http.StatusBadRequest)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"valid": verifier.valid(request.OperationID, request.Evidence, request.Receipt),
		})
	}), token)
	server := &http.Server{Handler: handler}
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func runLongRunningServer() {
	state := os.Getenv("PRAXO_STATE")
	token := os.Getenv("PRAXO_TOKEN")
	if state == "" || token == "" {
		fmt.Fprintln(os.Stderr, "missing PRAXO_STATE or PRAXO_TOKEN")
		os.Exit(1)
	}
	authority := effectAuthority(newEffectVerifier("fixture-effect-secret"))
	if verifierURL := os.Getenv("PRAXO_VERIFIER_URL"); verifierURL != "" {
		verifierToken := os.Getenv("PRAXO_VERIFIER_TOKEN")
		if verifierToken == "" {
			fmt.Fprintln(os.Stderr, "missing PRAXO_VERIFIER_TOKEN")
			os.Exit(1)
		}
		authority = &remoteEffectAuthority{
			url: strings.TrimRight(verifierURL, "/") + "/verify",
			token: verifierToken,
			client: &http.Client{Timeout: 5 * time.Second},
		}
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("LISTEN=%s\n", listener.Addr().String())
	service := newRemoteOperationsWithVerifier(state, authority)
	server := &http.Server{Handler: requireBearer(longRunningHandler(service), token)}
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func startTestProcess(t *testing.T, environment map[string]string) (*exec.Cmd, string) {
	t.Helper()
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	command := exec.Command(executable)
	command.Env = append([]string{}, os.Environ()...)
	for key, value := range environment {
		command.Env = append(command.Env, key+"="+value)
	}
	stdout, err := command.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	command.Stderr = os.Stderr
	if err := command.Start(); err != nil {
		t.Fatal(err)
	}
	lines := make(chan string, 1)
	go func() {
		line, _ := bufio.NewReader(stdout).ReadString('\n')
		lines <- line
	}()
	select {
	case line := <-lines:
		if !strings.HasPrefix(line, "LISTEN=") {
			_ = command.Process.Kill()
			t.Fatalf("unexpected server output: %q", line)
		}
		return command, "http://" + strings.TrimSpace(strings.TrimPrefix(line, "LISTEN="))
	case <-time.After(5 * time.Second):
		_ = command.Process.Kill()
		t.Fatal("server did not report its address")
		return nil, ""
	}
}

func startLongRunningServer(t *testing.T, state string) (*exec.Cmd, string) {
	t.Helper()
	return startTestProcess(t, map[string]string{
		"PRAXO_LONG_RUNNING_SERVER": "1",
		"PRAXO_STATE":               state,
		"PRAXO_TOKEN":               "secret",
	})
}

func startVerifier(t *testing.T, secret, token string) (*exec.Cmd, string) {
	t.Helper()
	return startTestProcess(t, map[string]string{
		"PRAXO_VERIFIER_SERVER": "1",
		"PRAXO_VERIFIER_SECRET": secret,
		"PRAXO_VERIFIER_TOKEN":  token,
	})
}

func stopLongRunningServer(command *exec.Cmd) {
	if command == nil || command.Process == nil {
		return
	}
	_ = command.Process.Kill()
	_ = command.Wait()
}

func getOperationToken(t *testing.T, client *http.Client, url, token string) remoteOperation {
	t.Helper()
	request, err := http.NewRequestWithContext(context.Background(), http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Authorization", "Bearer "+token)
	response, err := client.Do(request)
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

func TestLongRunningIndependentVerifier(t *testing.T) {
	state := filepath.Join(t.TempDir(), "operations.json")
	verifierCommand, verifierURL := startVerifier(t, "verifier-secret", "verify-token")
	defer stopLongRunningServer(verifierCommand)
	command, baseURL := startTestProcess(t, map[string]string{
		"PRAXO_LONG_RUNNING_SERVER": "1",
		"PRAXO_STATE":               state,
		"PRAXO_TOKEN":               "secret",
		"PRAXO_VERIFIER_URL":        verifierURL,
		"PRAXO_VERIFIER_TOKEN":      "verify-token",
	})
	defer stopLongRunningServer(command)
	client := &http.Client{Timeout: 5 * time.Second}

	status, body := postJSONToken(t, client, baseURL+"/operations", "secret", map[string]any{"key": "verifier-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("submit status=%d body=%s", status, body)
	}
	var submitted struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(body, &submitted); err != nil {
		t.Fatal(err)
	}
	status, body = postJSONToken(t, client, baseURL+"/operations/"+submitted.ID+"/complete", "secret", map[string]any{}, false)
	if status != http.StatusOK || !strings.Contains(string(body), "completed") {
		t.Fatalf("complete status=%d body=%s", status, body)
	}
	evidence := "room=kitchen;sensor=door"
	status, _ = postJSONToken(t, client, baseURL+"/operations/"+submitted.ID+"/verify-effect", "secret", map[string]any{
		"evidence": evidence, "receipt": "forged",
	}, false)
	if status != http.StatusConflict {
		t.Fatalf("forged receipt status=%d", status)
	}
	receipt := newEffectVerifier("verifier-secret").sign(submitted.ID, evidence)
	status, body = postJSONToken(t, client, baseURL+"/operations/"+submitted.ID+"/verify-effect", "secret", map[string]any{
		"evidence": evidence, "receipt": receipt,
	}, false)
	if status != http.StatusOK || !strings.Contains(string(body), "effect_verified") {
		t.Fatalf("verify status=%d body=%s", status, body)
	}
}

func TestLongRunningCrossProcessRestart(t *testing.T) {
	state := filepath.Join(t.TempDir(), "operations.json")
	command, baseURL := startLongRunningServer(t, state)
	defer stopLongRunningServer(command)
	client := &http.Client{Timeout: 5 * time.Second}

	status, body := postJSONToken(t, client, baseURL+"/operations", "secret", map[string]any{"key": "cross-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("submit status=%d body=%s", status, body)
	}
	var submitted struct {
		ID      string `json:"id"`
		Created bool   `json:"created"`
	}
	if err := json.Unmarshal(body, &submitted); err != nil {
		t.Fatal(err)
	}
	if !submitted.Created || submitted.ID == "" {
		t.Fatalf("submitted=%#v", submitted)
	}
	stopLongRunningServer(command)

	command, baseURL = startLongRunningServer(t, state)
	defer stopLongRunningServer(command)
	op := getOperationToken(t, client, baseURL+"/operations/"+submitted.ID, "secret")
	if op.State != remoteAccepted {
		t.Fatalf("state after restart=%s", op.State)
	}
	status, body = postJSONToken(t, client, baseURL+"/operations", "secret", map[string]any{"key": "cross-1"}, false)
	if status != http.StatusOK {
		t.Fatalf("recover status=%d body=%s", status, body)
	}
	if err := json.Unmarshal(body, &submitted); err != nil {
		t.Fatal(err)
	}
	if submitted.Created {
		t.Fatal("cross-process retry created a duplicate operation")
	}
}
