package formatter

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestListIsNotEmpty(t *testing.T) {
	if len(List()) == 0 {
		t.Fatal("expected registered formatters")
	}
}

func TestCommandFields(t *testing.T) {
	f := Formatter{Command: "gofmt -w $FILE"}
	fields := f.CommandFields()
	if len(fields) != 3 || fields[0] != "gofmt" || fields[2] != "$FILE" {
		t.Fatalf("fields = %+v", fields)
	}
	if got := (&Formatter{}).CommandFields(); len(got) != 0 {
		t.Fatalf("empty command fields = %+v", got)
	}
}

func TestListReturnsCopy(t *testing.T) {
	listed := List()
	listed[0].Name = "changed"
	if len(listed[0].Extensions) > 0 {
		listed[0].Extensions[0] = ".changed"
	}
	fresh := List()
	if fresh[0].Name == "changed" {
		t.Fatal("List returned the mutable registry")
	}
	if len(fresh[0].Extensions) > 0 && fresh[0].Extensions[0] == ".changed" {
		t.Fatal("List shared the extensions slice")
	}
}

func TestDetectUnknownExtension(t *testing.T) {
	if got := Detect("file.unknown"); got != nil {
		t.Fatalf("Detect unknown = %+v", got)
	}
}

func TestDetectIsCaseInsensitiveAndReturnsCopy(t *testing.T) {
	if _, err := exec.LookPath("gofmt"); err != nil {
		t.Skip("gofmt not installed")
	}
	detected := Detect("MAIN.GO")
	if detected == nil || detected.Name != "gofmt" {
		t.Fatalf("Detect = %+v", detected)
	}
	detected.Extensions[0] = ".changed"
	again := Detect("main.go")
	if again == nil || again.Extensions[0] != ".go" {
		t.Fatalf("Detect shared extensions: %+v", again)
	}
}

func TestFormatWithoutFormatter(t *testing.T) {
	out, err := Format("file.unknown")
	if err != nil || out != "" {
		t.Fatalf("Format = %q, %v", out, err)
	}
}

func TestRunRejectsEmptyCommand(t *testing.T) {
	out, err := (&Formatter{}).Run("file.go")
	if err == nil || out != "" {
		t.Fatalf("Run = %q, %v", out, err)
	}
}

func TestRunReportsCommandFailure(t *testing.T) {
	out, err := (&Formatter{Command: "praxo-nonexistent-formatter-command $FILE"}).Run("file.go")
	if err == nil {
		t.Fatalf("Run unexpectedly succeeded: %q", out)
	}
}

func TestFormatAllReportsMissingDirectory(t *testing.T) {
	formatted, err := NewWatch(filepath.Join(t.TempDir(), "missing")).FormatAll()
	if err == nil || len(formatted) != 0 {
		t.Fatalf("FormatAll = %v, %v", formatted, err)
	}
}

func TestFormatAllFormatsGoFile(t *testing.T) {
	if _, err := exec.LookPath("gofmt"); err != nil {
		t.Skip("gofmt not installed")
	}
	dir := t.TempDir()
	path := filepath.Join(dir, "sample.go")
	if err := os.WriteFile(path, []byte("package main\nfunc main(){println(\"x\")}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	formatted, err := NewWatch(dir).FormatAll()
	if err != nil {
		t.Fatal(err)
	}
	if len(formatted) != 1 || formatted[0] != path {
		t.Fatalf("formatted = %v", formatted)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "func main() {") {
		t.Fatalf("file was not formatted:\n%s", data)
	}
}

func TestFormatAllReportsFormatterFailure(t *testing.T) {
	if _, err := exec.LookPath("gofmt"); err != nil {
		t.Skip("gofmt not installed")
	}
	dir := t.TempDir()
	path := filepath.Join(dir, "broken.go")
	if err := os.WriteFile(path, []byte("package main\nfunc {{{"), 0o600); err != nil {
		t.Fatal(err)
	}
	formatted, err := NewWatch(dir).FormatAll()
	if err == nil {
		t.Fatalf("expected formatter error, formatted = %v", formatted)
	}
	if len(formatted) != 0 {
		t.Fatalf("formatted = %v", formatted)
	}
}
