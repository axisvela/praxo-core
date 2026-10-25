package spec

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func TestParityInventory(t *testing.T) {
	root := repoRoot(t)
	version := strings.TrimSpace(string(readFile(t, filepath.Join(root, "VERSION"))))
	api := string(readFile(t, filepath.Join(root, "api", version+".txt")))

	const prefix = "### github.com/axisvela/praxo-core/v2/"
	packages := map[string]bool{}
	for _, line := range strings.Split(api, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, prefix) {
			continue
		}
		pkg := strings.TrimPrefix(line, prefix)
		if strings.HasPrefix(pkg, "pkg/") {
			packages[pkg] = true
		}
	}
	if len(packages) == 0 {
		t.Fatalf("no packages found in api/%s.txt", version)
	}

	rows := parseParityRows(t, string(readFile(t, filepath.Join(root, vectorDir, "parity.md"))))
	seen := map[string]parityRow{}
	for _, row := range rows {
		if _, ok := seen[row.Package]; ok {
			t.Errorf("duplicate parity row for %s", row.Package)
		}
		seen[row.Package] = row
		for _, s := range row.SDK {
			switch s {
			case "planned", "partial", "parity", "n/a":
			default:
				t.Errorf("%s: invalid SDK status %q", row.Package, s)
			}
		}
		switch row.Phase {
		case "P1", "P2", "P3", "P4", "n/a":
		default:
			t.Errorf("%s: invalid phase %q", row.Package, row.Phase)
		}
		for _, s := range row.SDK {
			if s == "n/a" && row.Package != "pkg/conformance" && row.Package != "pkg/plugin/tck" {
				t.Errorf("%s: n/a is only allowed for Go-only harness packages", row.Package)
			}
		}
	}

	for pkg := range packages {
		if _, ok := seen[pkg]; !ok {
			t.Errorf("%s is exported but has no spec/parity.md row", pkg)
		}
	}
	for pkg := range seen {
		if !packages[pkg] {
			t.Errorf("%s has a parity row but is not in api/%s.txt", pkg, version)
		}
	}
}

func TestParitySymbols(t *testing.T) {
	root := repoRoot(t)
	version := strings.TrimSpace(string(readFile(t, filepath.Join(root, "VERSION"))))
	api := string(readFile(t, filepath.Join(root, "api", version+".txt")))
	sections := parseAPISections(api)

	md := string(readFile(t, filepath.Join(root, vectorDir, "parity.md")))
	seen := map[string]bool{}
	rows := 0
	for _, line := range strings.Split(md, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "| `") || strings.HasPrefix(line, "| `pkg/") {
			continue
		}
		cells := strings.Split(line, "|")
		if len(cells) < 7 {
			continue
		}
		sym := strings.Trim(strings.TrimSpace(cells[1]), "`")
		if !strings.Contains(sym, ".") {
			continue
		}
		rows++
		goSym := sym
		if !strings.HasPrefix(goSym, "pkg/") {
			goSym = "pkg/" + goSym
		}
		i := strings.LastIndex(goSym, ".")
		pkg, name := goSym[:i], goSym[i+1:]
		section, ok := sections[pkg]
		if !ok {
			t.Errorf("%s: package %s is not in api/%s.txt", sym, pkg, version)
			continue
		}
		pattern := regexp.MustCompile(`\b` + regexp.QuoteMeta(name) + `\b`)
		if !pattern.MatchString(section) {
			t.Errorf("%s: symbol %s is not in %s", sym, name, pkg)
		}
		key := pkg + "." + name
		if seen[key] {
			t.Errorf("duplicate symbol row %s", key)
		}
		seen[key] = true
		for _, idx := range []int{3, 4, 5} {
			if strings.TrimSpace(cells[idx]) == "" {
				t.Errorf("%s: empty SDK symbol column", sym)
			}
		}
	}
	if rows == 0 {
		t.Fatal("no symbol rows found in spec/parity.md")
	}
}

func parseAPISections(api string) map[string]string {
	const prefix = "### github.com/axisvela/praxo-core/v2/"
	out := map[string]string{}
	pkg := ""
	var b strings.Builder
	flush := func() {
		if pkg != "" {
			out[pkg] = b.String()
		}
		b.Reset()
	}
	for _, line := range strings.Split(api, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, prefix) {
			flush()
			pkg = strings.TrimPrefix(trimmed, prefix)
			if !strings.HasPrefix(pkg, "pkg/") {
				pkg = ""
			}
			continue
		}
		if pkg != "" {
			b.WriteString(line)
			b.WriteString("\n")
		}
	}
	flush()
	return out
}

type parityRow struct {
	Package string
	SDK     [3]string
	Phase   string
}

func parseParityRows(t *testing.T, md string) []parityRow {
	t.Helper()
	var out []parityRow
	for _, line := range strings.Split(md, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "| `pkg/") {
			continue
		}
		cells := strings.Split(line, "|")
		if len(cells) < 7 {
			t.Errorf("malformed parity row: %s", line)
			continue
		}
		pkg := strings.Trim(strings.TrimSpace(cells[1]), "`")
		out = append(out, parityRow{
			Package: pkg,
			SDK: [3]string{
				strings.TrimSpace(cells[3]),
				strings.TrimSpace(cells[4]),
				strings.TrimSpace(cells[5]),
			},
			Phase: strings.TrimSpace(cells[6]),
		})
	}
	if len(out) == 0 {
		t.Fatal("no package rows found in spec/parity.md")
	}
	return out
}

func TestSplitParity(t *testing.T) {
	root := repoRoot(t)
	version := strings.TrimSpace(string(readFile(t, filepath.Join(root, "VERSION"))))
	specVersion := strings.TrimSpace(string(readFile(t, filepath.Join(root, vectorDir, "SPEC_VERSION"))))
	api := string(readFile(t, filepath.Join(root, "api", version+".txt")))
	const prefix = "### github.com/axisvela/praxo-core/v2/"
	packages := map[string]bool{}
	for _, line := range strings.Split(api, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, prefix) {
			pkg := strings.TrimPrefix(line, prefix)
			if strings.HasPrefix(pkg, "pkg/") {
				packages[pkg] = true
			}
		}
	}

	required := []string{
		"rust", "c", "csharp", "swift", "php", "julia", "r", "haskell",
		"vbnet", "fortran", "lisp", "bridge-shell", "bridge-powershell",
	}
	validTier := map[string]bool{
		"core": true, "wire": true, "bridge": true, "sample": true,
	}
	validStatus := map[string]bool{
		"planned": true, "partial": true, "parity": true, "n/a": true,
	}
	validPhase := map[string]bool{
		"P1": true, "P2": true, "P3": true, "P4": true, "n/a": true,
	}
	for _, name := range required {
		path := filepath.Join(root, "spec", "parity", name+".md")
		data, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("%s: %v", path, err)
			continue
		}
		text := string(data)
		tier := metaValue(text, "- Tier:")
		if !validTier[tier] {
			t.Errorf("%s: invalid tier %q", name, tier)
		}
		if got := metaValue(text, "- SPEC_VERSION:"); got != specVersion {
			t.Errorf("%s: SPEC_VERSION %q, want %q", name, got, specVersion)
		}
		seen := map[string]bool{}
		for _, line := range strings.Split(text, "\n") {
			line = strings.TrimSpace(line)
			if !strings.HasPrefix(line, "| `") || strings.HasPrefix(line, "| `pkg/") {
				continue
			}
			cells := strings.Split(line, "|")
			if len(cells) < 6 {
				t.Errorf("%s: malformed row %s", name, line)
				continue
			}
			goSymbol := strings.Trim(cells[1], " `")
			languageSymbol := strings.Trim(cells[2], " `")
			status := strings.TrimSpace(cells[3])
			phase := strings.TrimSpace(cells[4])
			if !validStatus[status] {
				t.Errorf("%s: %s invalid status %q", name, goSymbol, status)
			}
			if !validPhase[phase] {
				t.Errorf("%s: %s invalid phase %q", name, goSymbol, phase)
			}
			if status == "parity" && languageSymbol == "" {
				t.Errorf("%s: %s parity row without language symbol", name, goSymbol)
			}
			if seen[goSymbol] {
				t.Errorf("%s: duplicate symbol %s", name, goSymbol)
			}
			seen[goSymbol] = true
			dot := strings.LastIndex(goSymbol, ".")
			if dot < 0 {
				t.Errorf("%s: %s is not a Go symbol", name, goSymbol)
				continue
			}
			pkg := goSymbol[:dot]
			if !strings.HasPrefix(pkg, "pkg/") {
				pkg = "pkg/" + pkg
			}
			if !packages[pkg] {
				t.Errorf("%s: %s is not in api/%s.txt", name, pkg, version)
			}
		}
	}
}

func metaValue(text, prefix string) string {
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, prefix) {
			return strings.TrimSpace(strings.TrimPrefix(line, prefix))
		}
	}
	return ""
}
