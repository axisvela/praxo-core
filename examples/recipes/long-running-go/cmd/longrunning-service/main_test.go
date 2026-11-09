package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
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

func TestStandaloneServiceLoadFault(t *testing.T) {
	raw := os.Getenv("PRAXO_LOAD_SUBMISSIONS")
	if raw == "" {
		t.Skip("PRAXO_LOAD_SUBMISSIONS is not set")
	}
	count, err := strconv.Atoi(raw)
	if err != nil || count < 2 {
		t.Fatalf("invalid PRAXO_LOAD_SUBMISSIONS=%q", raw)
	}
	binary := buildService(t)
	state := filepath.Join(t.TempDir(), "operations.json")
	command, addr := startService(t, binary, state, "secret", "")
	stopped := make(chan struct{})
	stopOnce := sync.Once{}
	kill := func() {
		stopOnce.Do(func() {
			stopService(command)
			close(stopped)
		})
	}

	acknowledged := make(chan string, count)
	failures := make(chan error, count)
	firstAck := make(chan struct{}, 1)
	var wait sync.WaitGroup
	for index := 0; index < count; index++ {
		wait.Add(1)
		go func(key string) {
			defer wait.Done()
			id, err := postOperationResult(addr, key)
			if err != nil {
				failures <- err
				return
			}
			acknowledged <- id
			select {
			case firstAck <- struct{}{}:
			default:
			}
		}(fmt.Sprintf("key-%d", index))
	}
	go func() {
		<-firstAck
		time.Sleep(50 * time.Millisecond)
		kill()
	}()

	wait.Wait()
	kill()
	close(acknowledged)
	close(failures)
	acked := map[string]bool{}
	for id := range acknowledged {
		acked[id] = true
	}
	if len(acked) == 0 {
		t.Fatal("no submissions were acknowledged before the fault")
	}

	command, addr = startService(t, binary, state, "secret", "")
	defer stopService(command)
	for id := range acked {
		if code := statusCode(t, addr, id); code != http.StatusOK {
			t.Fatalf("acknowledged operation %s was lost after the fault", id)
		}
	}
}

func postOperationResult(addr, key string) (string, error) {
	request, err := http.NewRequest(http.MethodPost, "http://"+addr+"/operations", strings.NewReader(`{"key":"`+key+`"}`))
	if err != nil {
		return "", err
	}
	request.Header.Set("Authorization", "Bearer secret")
	request.Header.Set("Content-Type", "application/json")
	response, err := (&http.Client{Timeout: 10 * time.Second}).Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("submit %s status=%d", key, response.StatusCode)
	}
	var submitted struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(response.Body).Decode(&submitted); err != nil {
		return "", err
	}
	if submitted.ID == "" {
		return "", fmt.Errorf("submit %s returned no id", key)
	}
	return submitted.ID, nil
}

func TestStandaloneServicePostgresLease(t *testing.T) {
	dsn := os.Getenv("PRAXO_POSTGRES_DSN")
	if dsn == "" {
		t.Skip("PRAXO_POSTGRES_DSN is not set")
	}
	if testing.Short() {
		t.Skip("standalone service test builds and runs a child process")
	}
	binary := buildService(t)
	state := filepath.Join(t.TempDir(), "operations.json")
	command, addr := startService(t, binary, state, "secret", "", "-lock-backend", "postgres", "-lock-dsn", dsn, "-lock-resource", "operations-service-test")
	defer stopService(command)

	id := postOperation(t, addr, "key-1")
	if code := statusCode(t, addr, id); code != http.StatusOK {
		t.Fatalf("status query status=%d", code)
	}
}

func TestStandaloneServiceTokenRotation(t *testing.T) {
	if testing.Short() {
		t.Skip("standalone service test builds and runs a child process")
	}
	binary := buildService(t)
	state := filepath.Join(t.TempDir(), "operations.json")
	tokenFile := filepath.Join(t.TempDir(), "token")
	if err := os.WriteFile(tokenFile, []byte("secret\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	command, addr := startService(t, binary, state, "ignored", "", "-token-file", tokenFile)
	defer stopService(command)

	if code := postOperationToken(addr, "key-1", "secret"); code != http.StatusOK {
		t.Fatalf("original token status=%d", code)
	}
	if err := os.WriteFile(tokenFile, []byte("rotated\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if code := postOperationToken(addr, "key-2", "secret"); code != http.StatusUnauthorized {
		t.Fatalf("rotated-out token status=%d", code)
	}
	if code := postOperationToken(addr, "key-3", "rotated"); code != http.StatusOK {
		t.Fatalf("rotated-in token status=%d", code)
	}
}

func postOperationToken(addr, key, token string) int {
	request, err := http.NewRequest(http.MethodPost, "http://"+addr+"/operations", strings.NewReader(`{"key":"`+key+`"}`))
	if err != nil {
		return 0
	}
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("Content-Type", "application/json")
	response, err := (&http.Client{Timeout: 5 * time.Second}).Do(request)
	if err != nil {
		return 0
	}
	defer response.Body.Close()
	return response.StatusCode
}

func TestStandaloneServiceMetricsNames(t *testing.T) {
	if testing.Short() {
		t.Skip("standalone service test builds and runs a child process")
	}
	binary := buildService(t)
	state := filepath.Join(t.TempDir(), "operations.json")
	command, addr := startService(t, binary, state, "secret", "")
	defer stopService(command)

	response, err := (&http.Client{Timeout: 5 * time.Second}).Get("http://" + addr + "/metrics")
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{
		"praxo_longrunning_http_requests_total",
		"praxo_longrunning_http_errors_total",
		"praxo_longrunning_operations_total",
	} {
		if !strings.Contains(string(body), name) {
			t.Fatalf("metrics missing %s:\n%s", name, body)
		}
	}
}

func TestStandaloneServiceConcurrentSubmits(t *testing.T) {
	if testing.Short() {
		t.Skip("standalone service test builds and runs a child process")
	}
	binary := buildService(t)
	state := filepath.Join(t.TempDir(), "operations.json")
	command, addr := startService(t, binary, state, "secret", "")
	defer stopService(command)

	const count = 20
	var wait sync.WaitGroup
	failures := make(chan error, count)
	for index := 0; index < count; index++ {
		wait.Add(1)
		go func(key string) {
			defer wait.Done()
			request, err := http.NewRequest(http.MethodPost, "http://"+addr+"/operations", strings.NewReader(`{"key":"`+key+`"}`))
			if err != nil {
				failures <- err
				return
			}
			request.Header.Set("Authorization", "Bearer secret")
			request.Header.Set("Content-Type", "application/json")
			response, err := (&http.Client{Timeout: 10 * time.Second}).Do(request)
			if err != nil {
				failures <- err
				return
			}
			defer response.Body.Close()
			if response.StatusCode != http.StatusOK {
				failures <- fmt.Errorf("submit %s status=%d", key, response.StatusCode)
			}
		}(fmt.Sprintf("key-%d", index))
	}
	wait.Wait()
	close(failures)
	for err := range failures {
		t.Fatal(err)
	}

	data, err := os.ReadFile(state)
	if err != nil {
		t.Fatal(err)
	}
	var persisted struct {
		Effects    int
		Operations []struct{ ID string }
	}
	if err := json.Unmarshal(data, &persisted); err != nil {
		t.Fatal(err)
	}
	if persisted.Effects != count || len(persisted.Operations) != count {
		t.Fatalf("effects=%d operations=%d, want %d", persisted.Effects, len(persisted.Operations), count)
	}

	response, err := (&http.Client{Timeout: 5 * time.Second}).Get("http://" + addr + "/metrics")
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(body), fmt.Sprintf("praxo_longrunning_operations_total %d", count)) {
		t.Fatalf("metrics did not report %d operations:\n%s", count, body)
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
