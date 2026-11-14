package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"strings"
	"testing"
)

func TestAllowedTool(t *testing.T) {
	output, calls, err := runScenario(context.Background(), "public")
	if err != nil || output != "recorded" || calls != 1 {
		t.Fatalf("output=%q effects=%d error=%v", output, calls, err)
	}
}

func TestDeniedToolHasNoEffect(t *testing.T) {
	output, calls, err := runScenario(context.Background(), "private")
	if err == nil || !strings.Contains(err.Error(), "tool.invoke denied") {
		t.Fatalf("expected policy denial, got %v", err)
	}
	if calls != 0 || output != "" {
		t.Fatalf("denied call: output=%q effects=%d", output, calls)
	}
}

func TestStarterOutput(t *testing.T) {
	var out bytes.Buffer
	if err := run(context.Background(), &out); err != nil {
		t.Fatal(err)
	}
	if want := "allow: recorded; effects=1\ndeny: policy rejected; effects=0\n"; out.String() != want {
		t.Fatalf("output=%q, want %q", out.String(), want)
	}
}

func TestPublishedDependency(t *testing.T) {
	cmd := exec.Command("go", "list", "-mod=readonly", "-m", "-json", "all")
	cmd.Env = append(os.Environ(), "GOWORK=off")
	output, err := cmd.Output()
	if err != nil {
		t.Fatal(err)
	}
	decoder := json.NewDecoder(bytes.NewReader(output))
	found := false
	for {
		var dependency struct {
			Path    string
			Version string
			Replace json.RawMessage
		}
		if err := decoder.Decode(&dependency); err == io.EOF {
			break
		} else if err != nil {
			t.Fatal(err)
		}
		if len(dependency.Replace) != 0 {
			t.Fatalf("local replacement for %s", dependency.Path)
		}
		if dependency.Path == "github.com/axisvela/praxo-core/v2" {
			found = true
			if dependency.Version != "v2.7.0" {
				t.Fatalf("Core version=%q, want v2.7.0", dependency.Version)
			}
		}
	}
	if !found {
		t.Fatal("published Core dependency missing")
	}
}
