package agentcontext

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadAgentsMDOrderAndHeaders(t *testing.T) {
	dir := t.TempDir()
	a := filepath.Join(dir, "AGENTS.md")
	b := filepath.Join(dir, "EXTRA.md")
	if err := os.WriteFile(a, []byte("first"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(b, []byte("second"), 0o600); err != nil {
		t.Fatal(err)
	}
	got, err := LoadAgentsMD(a, b)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "## AGENTS.md: "+a) || !strings.Contains(got, "first") {
		t.Fatalf("first file missing: %q", got)
	}
	if strings.Index(got, "first") > strings.Index(got, "second") {
		t.Fatalf("file order changed: %q", got)
	}
}

func TestLoadAgentsMDMissingFile(t *testing.T) {
	if _, err := LoadAgentsMD(filepath.Join(t.TempDir(), "missing.md")); err == nil {
		t.Fatal("missing file accepted")
	}
}

func TestLoadAgentsMDBounded(t *testing.T) {
	p := filepath.Join(t.TempDir(), "AGENTS.md")
	if err := os.WriteFile(p, []byte(strings.Repeat("x", MaxAgentsMDBytes*2)), 0o600); err != nil {
		t.Fatal(err)
	}
	got, err := LoadAgentsMD(p)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) > MaxAgentsMDBytes+32 {
		t.Fatalf("loaded %d bytes, want bounded", len(got))
	}
	if !strings.Contains(got, "[truncated]") {
		t.Fatal("truncation marker missing")
	}
}
