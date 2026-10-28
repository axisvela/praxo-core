package spec

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"testing"
)

type vectorFile struct {
	SpecVersion string       `json:"specVersion"`
	Group       string       `json:"group"`
	Vectors     []vectorCase `json:"vectors"`
}

type vectorCase struct {
	ID          string          `json:"id"`
	Description string          `json:"description"`
	Input       json.RawMessage `json:"input"`
	Expect      json.RawMessage `json:"expect"`
}

var requiredVectorGroups = []string{
	"agent-loop", "checkpoint", "context", "event", "jsonschema", "memory",
	"middleware", "plugin", "policy", "stream", "toolcall",
}

func TestVectors(t *testing.T) {
	root := repoRoot(t)
	version := strings.TrimSpace(string(readFile(t, filepath.Join(root, vectorDir, "SPEC_VERSION"))))
	files := loadVectorFiles(t, root)
	if len(files) == 0 {
		t.Fatal("no vector files")
	}
	for _, problem := range vectorInventoryProblems(files, version) {
		t.Error(problem)
	}
	for _, f := range files {
		f := f
		t.Run(f.Group, func(t *testing.T) {
			for _, v := range f.Vectors {
				v := v
				t.Run(v.ID, func(t *testing.T) {
					if err := runVector(f.Group, v); err != nil {
						t.Fatal(err)
					}
				})
			}
		})
	}
}

func vectorInventoryProblems(files []vectorFile, version string) []string {
	var problems []string
	seenIDs := map[string]string{}
	seenGroups := map[string]bool{}
	required := map[string]bool{}
	for _, group := range requiredVectorGroups {
		required[group] = true
	}
	for _, f := range files {
		seenGroups[f.Group] = true
		if f.SpecVersion != version {
			problems = append(problems, f.Group+": specVersion "+f.SpecVersion+", want "+version)
		}
		if !required[f.Group] {
			problems = append(problems, f.Group+": unexpected vector group")
		}
		if len(f.Vectors) == 0 {
			problems = append(problems, f.Group+": vector group is empty")
		}
		for _, v := range f.Vectors {
			if v.ID == "" {
				problems = append(problems, f.Group+": vector without id")
				continue
			}
			if previous, ok := seenIDs[v.ID]; ok {
				problems = append(problems, "duplicate vector id "+v.ID+" in "+previous+" and "+f.Group)
			}
			seenIDs[v.ID] = f.Group
		}
	}
	for _, group := range requiredVectorGroups {
		if !seenGroups[group] {
			problems = append(problems, "missing required vector group "+group)
		}
	}
	return problems
}

func TestVectorInventoryRejectsMissingEmptyDuplicateAndVersion(t *testing.T) {
	files := []vectorFile{{
		SpecVersion: "0.1.0",
		Group:       "toolcall",
		Vectors:     []vectorCase{{ID: "same"}},
	}}
	problems := strings.Join(vectorInventoryProblems(files, "0.2.0"), "\n")
	for _, want := range []string{
		"specVersion 0.1.0, want 0.2.0",
		"missing required vector group agent-loop",
		"missing required vector group stream",
	} {
		if !strings.Contains(problems, want) {
			t.Errorf("problems do not contain %q:\n%s", want, problems)
		}
	}
	files[0].SpecVersion = "0.2.0"
	event := vectorFile{SpecVersion: "0.2.0", Group: "event", Vectors: []vectorCase{{ID: "same"}, {ID: ""}}}
	empty := vectorFile{SpecVersion: "0.2.0", Group: "plugin"}
	files = append(files, event, empty)
	problems = strings.Join(vectorInventoryProblems(files, "0.2.0"), "\n")
	for _, want := range []string{
		"plugin: vector group is empty",
		"duplicate vector id same",
		"event: vector without id",
	} {
		if !strings.Contains(problems, want) {
			t.Errorf("problems do not contain %q:\n%s", want, problems)
		}
	}
}

func repoRoot(t *testing.T) string {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	dir := filepath.Dir(file)
	for {
		if _, err := os.Stat(filepath.Join(dir, vectorDir, "SPEC_VERSION")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatalf("repository root not found from %s", file)
		}
		dir = parent
	}
}

func loadVectorFiles(t *testing.T, root string) []vectorFile {
	t.Helper()
	dir := filepath.Join(root, vectorDir, "vectors")
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
	var out []vectorFile
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		var f vectorFile
		readJSONFile(t, filepath.Join(dir, entry.Name()), &f)
		want := strings.TrimSuffix(entry.Name(), ".json")
		if f.Group != want {
			t.Errorf("%s: group %q, want %q", entry.Name(), f.Group, want)
		}
		out = append(out, f)
	}
	return out
}

func readJSONFile(t *testing.T, path string, v any) {
	t.Helper()
	if err := json.Unmarshal(readFile(t, path), v); err != nil {
		t.Fatalf("%s: %v", path, err)
	}
}

func readFile(t *testing.T, path string) []byte {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return b
}
