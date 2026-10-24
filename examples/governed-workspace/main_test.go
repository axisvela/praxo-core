package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
)

func TestReadOnlyMode(t *testing.T) {
	dir := t.TempDir()
	if err := seed(dir); err != nil {
		t.Fatal(err)
	}
	output, trace, err := runDemo(context.Background(), "read", dir)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output, "Quarterly status") {
		t.Fatalf("output = %q", output)
	}
	if _, err := os.Stat(filepath.Join(dir, "notes.md")); !os.IsNotExist(err) {
		t.Fatalf("read mode wrote notes.md: %v", err)
	}
	assertTrace(t, trace, "tool.call:fs.read", true)
	assertTrace(t, trace, "tool.interrupt", false)
	assertTrace(t, trace, "run.completed", true)
}

func TestApprovedWrite(t *testing.T) {
	dir := t.TempDir()
	if err := seed(dir); err != nil {
		t.Fatal(err)
	}
	output, trace, err := runDemo(context.Background(), "write", dir)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output, "approved") {
		t.Fatalf("output = %q", output)
	}
	data, err := os.ReadFile(filepath.Join(dir, "notes.md"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "approved by demo\n" {
		t.Fatalf("notes = %q", data)
	}
	assertTrace(t, trace, "tool.interrupt:fs.write", true)
	assertTrace(t, trace, "tool.call:fs.write", true)
	assertTrace(t, trace, "run.completed", true)
}

func TestDeniedWriteDoesNotExecute(t *testing.T) {
	dir := t.TempDir()
	if err := seed(dir); err != nil {
		t.Fatal(err)
	}
	_, trace, err := runDemo(context.Background(), "deny", dir)
	if !errors.Is(err, agent.ErrApprovalDenied) {
		t.Fatalf("err = %v, want ErrApprovalDenied", err)
	}
	if _, statErr := os.Stat(filepath.Join(dir, "notes.md")); !os.IsNotExist(statErr) {
		t.Fatalf("denied write created notes.md: %v", statErr)
	}
	assertTrace(t, trace, "tool.interrupt:fs.write", true)
	assertTrace(t, trace, "tool.call:fs.write", false)
}

func TestEscapingPathDeniedBeforeTool(t *testing.T) {
	dir := t.TempDir()
	if err := seed(dir); err != nil {
		t.Fatal(err)
	}
	_, trace, err := runDemo(context.Background(), "escape", dir)
	if err == nil || !strings.Contains(err.Error(), "denied") {
		t.Fatalf("err = %v, want policy denial", err)
	}
	assertTrace(t, trace, "tool.call:fs.read", false)
	assertTrace(t, trace, "run.failed", true)
}

func assertTrace(t *testing.T, trace []string, want string, present bool) {
	t.Helper()
	found := false
	for _, entry := range trace {
		if entry == want {
			found = true
			break
		}
	}
	if found != present {
		t.Fatalf("trace %v contains %q = %v, want %v", trace, want, found, present)
	}
}
