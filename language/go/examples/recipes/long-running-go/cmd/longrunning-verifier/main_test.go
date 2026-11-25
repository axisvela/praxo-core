package main

import (
	"bufio"
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
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

func TestStandaloneVerifier(t *testing.T) {
	if testing.Short() {
		t.Skip("standalone verifier test builds and runs a child process")
	}
	binary := filepath.Join(t.TempDir(), "longrunning-verifier")
	if runtime.GOOS == "windows" {
		binary += ".exe"
	}
	build := exec.Command("go", "build", "-o", binary, ".")
	build.Stderr = os.Stderr
	if err := build.Run(); err != nil {
		t.Fatal(err)
	}

	command := exec.Command(binary, "-addr", "127.0.0.1:0", "-token", "secret", "-secret", "verifier-secret")
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
		t.Fatal("verifier did not report a listen address")
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

	operationID := "op-key-1"
	evidence := "room=kitchen;sensor=door"
	receipt := sign("verifier-secret", operationID, evidence)
	if !verify(t, client, addr, operationID, evidence, receipt) {
		t.Fatal("valid receipt was rejected")
	}
	if verify(t, client, addr, operationID, evidence, "forged") {
		t.Fatal("forged receipt was accepted")
	}
}

func verify(t *testing.T, client *http.Client, addr, operationID, evidence, receipt string) bool {
	t.Helper()
	body, err := json.Marshal(map[string]string{
		"operation_id": operationID,
		"evidence":     evidence,
		"receipt":      receipt,
	})
	if err != nil {
		t.Fatal(err)
	}
	request, err := http.NewRequest(http.MethodPost, "http://"+addr+"/verify", bytes.NewReader(body))
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
		t.Fatalf("verify status=%d", response.StatusCode)
	}
	var result struct {
		Valid bool `json:"valid"`
	}
	if err := json.NewDecoder(response.Body).Decode(&result); err != nil {
		t.Fatal(err)
	}
	return result.Valid
}

func sign(secret, operationID, evidence string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(operationID + "\n" + evidence))
	return hex.EncodeToString(mac.Sum(nil))
}
