// Package format provides language-specific code formatters.
// Reference: OpenCode's format/ system — auto-detects formatters from config files.
package format

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Formatter describes a code formatter for a specific language.
type Formatter struct {
	Name       string   `json:"name"`
	Extensions []string `json:"extensions"`
	Command    string   `json:"command"` // command + args template, $FILE is replaced
}

// Detect returns the appropriate formatter for a file path.
func Detect(filePath string) *Formatter {
	ext := strings.ToLower(filepath.Ext(filePath))
	for _, f := range formatters {
		for _, e := range f.Extensions {
			if e == ext {
				if f.isAvailable() {
					return &f
				}
			}
		}
	}
	return nil
}

// Format runs the detected formatter on a file.
func Format(filePath string) (string, error) {
	f := Detect(filePath)
	if f == nil {
		return "", nil // no formatter found, not an error
	}
	return f.Run(filePath)
}

// Run executes the formatter on the given file.
func (f *Formatter) Run(filePath string) (string, error) {
	args := make([]string, len(f.CommandFields()))
	for i, field := range f.CommandFields() {
		if field == "$FILE" {
			args[i] = filePath
		} else {
			args[i] = field
		}
	}
	cmd := exec.Command(args[0], args[1:]...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// CommandFields splits the command string into fields.
func (f *Formatter) CommandFields() []string {
	return strings.Fields(f.Command)
}

func (f *Formatter) isAvailable() bool {
	fields := f.CommandFields()
	if len(fields) == 0 {
		return false
	}
	_, err := exec.LookPath(fields[0])
	return err == nil
}

// AllAvailable returns all formatters that are installed on the system.
func AllAvailable() []Formatter {
	var available []Formatter
	for _, f := range formatters {
		if f.isAvailable() {
			available = append(available, f)
		}
	}
	return available
}

// List returns all registered formatters (regardless of availability).
func List() []Formatter {
	return formatters
}

var formatters = []Formatter{
	{Name: "gofmt", Extensions: []string{".go"}, Command: "gofmt -w $FILE"},
	{Name: "rustfmt", Extensions: []string{".rs"}, Command: "rustfmt $FILE"},
	{Name: "prettier", Extensions: []string{".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx", ".mts", ".cts", ".html", ".css", ".scss", ".less", ".vue", ".svelte", ".json", ".jsonc", ".yaml", ".yml", ".toml", ".md", ".mdx", ".graphql"}, Command: "prettier --write $FILE"},
	{Name: "biome", Extensions: []string{".js", ".jsx", ".ts", ".tsx", ".json", ".jsonc"}, Command: "biome format --write $FILE"},
	{Name: "ruff-format", Extensions: []string{".py", ".pyi"}, Command: "ruff format $FILE"},
	{Name: "black", Extensions: []string{".py", ".pyi"}, Command: "black $FILE"},
	{Name: "shfmt", Extensions: []string{".sh", ".bash"}, Command: "shfmt -w $FILE"},
	{Name: "clang-format", Extensions: []string{".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp"}, Command: "clang-format -i $FILE"},
	{Name: "zig-fmt", Extensions: []string{".zig", ".zon"}, Command: "zig fmt $FILE"},
	{Name: "ktlint", Extensions: []string{".kt", ".kts"}, Command: "ktlint -F $FILE"},
	{Name: "terraform-fmt", Extensions: []string{".tf", ".tfvars"}, Command: "terraform fmt $FILE"},
	{Name: "rubocop", Extensions: []string{".rb", ".rake", ".gemspec", ".ru"}, Command: "rubocop --autocorrect $FILE"},
	{Name: "dart-format", Extensions: []string{".dart"}, Command: "dart format $FILE"},
	{Name: "nixfmt", Extensions: []string{".nix"}, Command: "nixfmt $FILE"},
	{Name: "gleam-format", Extensions: []string{".gleam"}, Command: "gleam format $FILE"},
	{Name: "latexindent", Extensions: []string{".tex"}, Command: "latexindent -w -s $FILE"},
}

// WatchFormat watches a directory and formats files on change.
type WatchFormat struct {
	dir string
}

func NewWatch(dir string) *WatchFormat {
	return &WatchFormat{dir: dir}
}

func (w *WatchFormat) FormatAll() ([]string, error) {
	var formatted []string
	filepath.Walk(w.dir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		f := Detect(path)
		if f == nil {
			return nil
		}
		if _, err := f.Run(path); err == nil {
			formatted = append(formatted, path)
		}
		return nil
	})
	return formatted, nil
}
