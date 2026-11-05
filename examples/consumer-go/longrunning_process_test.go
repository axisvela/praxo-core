package main

import (
	"bufio"
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

func TestMain(m *testing.M) {
	if os.Getenv("PRAXO_LONG_RUNNING_SERVER") == "1" {
		runLongRunningServer()
		return
	}
	os.Exit(m.Run())
}

func runLongRunningServer() {
	state := os.Getenv("PRAXO_STATE")
	token := os.Getenv("PRAXO_TOKEN")
	if state == "" || token == "" {
		fmt.Fprintln(os.Stderr, "missing PRAXO_STATE or PRAXO_TOKEN")
		os.Exit(1)
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("LISTEN=%s\n", listener.Addr().String())
	service := newRemoteOperationsAt(state)
	server := &http.Server{Handler: requireBearer(longRunningHandler(service), token)}
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func startLongRunningServer(t *testing.T, state string) (*exec.Cmd, string) {
	t.Helper()
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	command := exec.Command(executable)
	command.Env = append(os.Environ(),
		"PRAXO_LONG_RUNNING_SERVER=1",
		"PRAXO_STATE="+state,
		"PRAXO_TOKEN=secret",
	)
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
