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

func TestStandaloneService(t *testing.T) {
	if testing.Short() {
		t.Skip("standalone service test builds and runs a child process")
	}
	state := filepath.Join(t.TempDir(), "operations.json")
	binary := filepath.Join(t.TempDir(), "longrunning-service")
	if runtime.GOOS == "windows" {
		binary += ".exe"
	}
	build := exec.Command("go", "build", "-o", binary, ".")
	build.Stderr = os.Stderr
	if err := build.Run(); err != nil {
		t.Fatal(err)
	}

	command := exec.Command(binary, "-addr", "127.0.0.1:0", "-state", state, "-token", "secret")
	command.WaitDelay = 5 * time.Second
	stdout, err := command.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	command.Stderr = os.Stderr
	if err := command.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() {
		_ = command.Process.Kill()
		_ = command.Wait()
	}()

	scanner := bufio.NewScanner(stdout)
	addr := ""
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "LISTEN=") {
			addr = strings.TrimPrefix(line, "LISTEN=")
			break
		}
	}
	if addr == "" {
		t.Fatal("service did not report a listen address")
	}

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

	request, err := http.NewRequest(http.MethodPost, "http://"+addr+"/operations", strings.NewReader(`{"key":"key-1"}`))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Authorization", "Bearer secret")
	request.Header.Set("Content-Type", "application/json")
	response, err := client.Do(request)
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

	request, err = http.NewRequest(http.MethodGet, "http://"+addr+"/operations/"+submitted.ID, nil)
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Authorization", "Bearer secret")
	response, err = client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("status query status=%d", response.StatusCode)
	}
}
