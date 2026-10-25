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

func TestVectors(t *testing.T) {
	root := repoRoot(t)
	version := strings.TrimSpace(string(readFile(t, filepath.Join(root, vectorDir, "SPEC_VERSION"))))
	files := loadVectorFiles(t, root)
	if len(files) == 0 {
		t.Fatal("no vector files")
	}
	seen := map[string]string{}
	for _, f := range files {
		f := f
		if f.SpecVersion != version {
			t.Errorf("%s: specVersion %q, want %q", f.Group, f.SpecVersion, version)
		}
		for _, v := range f.Vectors {
			if v.ID == "" {
				t.Errorf("%s: vector without id", f.Group)
				continue
			}
			if prev, ok := seen[v.ID]; ok {
				t.Errorf("duplicate vector id %q in %s and %s", v.ID, prev, f.Group)
			}
			seen[v.ID] = f.Group
		}
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
