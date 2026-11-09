package main

import (
	"bufio"
	"encoding/json"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

func buildService(t *testing.T) string {
	t.Helper()
	binary := filepath.Join(t.TempDir(), "longrunning-service")
	if runtime.GOOS == "windows" {
		binary += ".exe"
	}
	build := exec.Command("go", "build", "-o", binary, ".")
	build.Stderr = os.Stderr
	if err := build.Run(); err != nil {
		t.Fatal(err)
	}
	return binary
}

func startService(t *testing.T, binary, state, token, crashAt string, extra ...string) (*exec.Cmd, string) {
	t.Helper()
	args := []string{"-addr", "127.0.0.1:0", "-state", state, "-token", token, "-lock-ttl", "1s"}
	args = append(args, extra...)
	command := exec.Command(binary, args...)
	command.Env = append(os.Environ(), "PRAXO_CRASH_AT="+crashAt)
	command.WaitDelay = 5 * time.Second
	stdout, err := command.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	command.Stderr = os.Stderr
	if err := command.Start(); err != nil {
		t.Fatal(err)
	}
	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "LISTEN=") {
			addr := strings.TrimPrefix(line, "LISTEN=")
			return command, addr
		}
	}
	_ = command.Process.Kill()
	_ = command.Wait()
	t.Fatal("service did not report a listen address")
	return nil, ""
}

func stopService(command *exec.Cmd) {
	_ = command.Process.Kill()
	_ = command.Wait()
}

func waitExit(t *testing.T, command *exec.Cmd, want int) {
	t.Helper()
	done := make(chan error, 1)
	go func() { done <- command.Wait() }()
	select {
	case err := <-done:
		exitError, ok := err.(*exec.ExitError)
		if !ok || exitError.ExitCode() != want {
			t.Fatalf("exit error=%v, want code %d", err, want)
		}
	case <-time.After(10 * time.Second):
		_ = command.Process.Kill()
		t.Fatal("service did not exit")
	}
}

func postOperation(t *testing.T, addr, key string) string {
	t.Helper()
	request, err := http.NewRequest(http.MethodPost, "http://"+addr+"/operations", strings.NewReader(`{"key":"`+key+`"}`))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Authorization", "Bearer secret")
	request.Header.Set("Content-Type", "application/json")
	response, err := (&http.Client{Timeout: 5 * time.Second}).Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("submit status=%d", response.StatusCode)
	}
	var submitted struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(response.Body).Decode(&submitted); err != nil {
		t.Fatal(err)
	}
	if submitted.ID == "" {
		t.Fatal("submit did not return an operation id")
	}
	return submitted.ID
}

func postOperationIgnoringError(addr, key string) {
	request, err := http.NewRequest(http.MethodPost, "http://"+addr+"/operations", strings.NewReader(`{"key":"`+key+`"}`))
	if err != nil {
		return
	}
	request.Header.Set("Authorization", "Bearer secret")
	request.Header.Set("Content-Type", "application/json")
	response, err := (&http.Client{Timeout: 5 * time.Second}).Do(request)
	if err == nil {
		_ = response.Body.Close()
	}
}

func statusCode(t *testing.T, addr, id string) int {
	t.Helper()
	request, err := http.NewRequest(http.MethodGet, "http://"+addr+"/operations/"+id, nil)
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Authorization", "Bearer secret")
	response, err := (&http.Client{Timeout: 5 * time.Second}).Do(request)
	if err != nil {
		t.Fatal(err)
	}
	_ = response.Body.Close()
	return response.StatusCode
}

func TestStandaloneService(t *testing.T) {
	if testing.Short() {
		t.Skip("standalone service test builds and runs a child process")
	}
	binary := buildService(t)
	state := filepath.Join(t.TempDir(), "operations.json")
	command, addr := startService(t, binary, state, "secret", "")
	defer stopService(command)

	client := &http.Client{Timeout: 5 * time.Second}
	for _, path := range []string{"/healthz", "/readyz"} {
		response, err := client.Get("http://" + addr + path)
		if err != nil {
			t.Fatal(err)
		}
		_ = response.Body.Close()
		if response.StatusCode != http.StatusOK {
			t.Fatalf("%s status=%d", path, response.StatusCode)
		}
	}

	id := postOperation(t, addr, "key-1")
	if code := statusCode(t, addr, id); code != http.StatusOK {
		t.Fatalf("status query status=%d", code)
	}
}

func TestStandaloneServiceSQLiteLease(t *testing.T) {
	if testing.Short() {
		t.Skip("standalone service test builds and runs a child process")
	}
	binary := buildService(t)
	state := filepath.Join(t.TempDir(), "operations.json")
	dsn := "file:" + filepath.Join(t.TempDir(), "lease.db") + "?_pragma=busy_timeout(5000)"
	command, addr := startService(t, binary, state, "secret", "", "-lock-backend", "sqlite", "-lock-dsn", dsn)
	defer stopService(command)

	id := postOperation(t, addr, "key-1")
	if code := statusCode(t, addr, id); code != http.StatusOK {
		t.Fatalf("status query status=%d", code)
	}
}

func TestStandaloneServiceCrashRecovery(t *testing.T) {
	if testing.Short() {
		t.Skip("crash recovery test builds and runs child processes")
	}
	binary := buildService(t)
	state := filepath.Join(t.TempDir(), "operations.json")

	command, addr := startService(t, binary, state, "secret", "")
	postOperation(t, addr, "key-1")
	stopService(command)

	command, addr = startService(t, binary, state, "secret", "before-rename")
	postOperationIgnoringError(addr, "key-2")
	waitExit(t, command, 42)

	command, addr = startService(t, binary, state, "secret", "")
	if code := statusCode(t, addr, "op-key-1"); code != http.StatusOK {
		t.Fatalf("committed operation missing after pre-rename crash: status=%d", code)
	}
	if code := statusCode(t, addr, "op-key-2"); code != http.StatusNotFound {
		t.Fatalf("uncommitted operation survived pre-rename crash: status=%d", code)
	}
	stopService(command)

	command, addr = startService(t, binary, state, "secret", "after-rename")
	postOperationIgnoringError(addr, "key-3")
	waitExit(t, command, 42)

	command, addr = startService(t, binary, state, "secret", "")
	defer stopService(command)
	if code := statusCode(t, addr, "op-key-3"); code != http.StatusOK {
		t.Fatalf("committed operation missing after post-rename crash: status=%d", code)
	}
}
