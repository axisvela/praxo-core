package spec

import (
	"fmt"
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
	symbols := parseAPISymbols(api)
	inventories, problems := discoverSplitParity(root)
	for _, problem := range problems {
		t.Error(problem)
	}
	for name, text := range inventories {
		t.Run(name, func(t *testing.T) {
			for _, problem := range validateSplitParity(text, specVersion, symbols) {
				t.Error(problem)
			}
		})
	}
}

func discoverSplitParity(root string) (map[string]string, []string) {
	inventories := map[string]string{}
	var problems []string
	matrix, err := os.ReadFile(filepath.Join(root, "spec", "languages.md"))
	if err != nil {
		return inventories, []string{err.Error()}
	}
	type scope struct{ language, tier, status string }
	scopes := map[string]scope{}
	samples := map[string]scope{}
	inMatrix := false
	for _, line := range strings.Split(string(matrix), "\n") {
		if strings.HasPrefix(line, "## ") {
			inMatrix = strings.TrimSpace(line) == "## Matrix"
		}
		if !inMatrix {
			continue
		}
		cells := strings.Split(line, "|")
		if len(cells) != 8 {
			continue
		}
		language := strings.TrimSpace(cells[1])
		tiers := strings.Fields(cells[2])
		if len(tiers) == 0 {
			problems = append(problems, fmt.Sprintf("%s: empty language tier", language))
			continue
		}
		tier := strings.ToLower(tiers[0])
		s := scope{language, tier, strings.TrimSpace(cells[3])}
		if tier == "sample" {
			samples[strings.ToLower(language)] = s
			continue
		}
		tag := strings.Trim(strings.TrimSpace(cells[4]), "`")
		if slug, _, ok := strings.Cut(tag, "/v"); ok {
			if _, exists := scopes[slug]; exists {
				problems = append(problems, fmt.Sprintf("duplicate language release scope %s", slug))
			}
			scopes[slug] = s
		} else if s.status == "released" && tier == "core" && !strings.Contains(cells[2], "(reference)") {
			problems = append(problems, fmt.Sprintf("%s: released Core language has no release-tag scope", language))
		}
	}
	if len(scopes) == 0 {
		problems = append(problems, "no language release scopes found in spec/languages.md")
	}
	entries, err := os.ReadDir(filepath.Join(root, "spec", "parity"))
	if err != nil {
		return inventories, append(problems, err.Error())
	}
	seen := map[string]bool{}
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".md" || entry.Name() == "README.md" {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), ".md")
		data, err := os.ReadFile(filepath.Join(root, "spec", "parity", entry.Name()))
		if err != nil {
			problems = append(problems, err.Error())
			continue
		}
		text := string(data)
		inventories[name] = text
		key := strings.TrimPrefix(name, "bridge-")
		s, ok := scopes[key]
		if metaValue(text, "- Tier:") == "sample" {
			heading := strings.TrimSuffix(strings.TrimPrefix(strings.TrimSpace(strings.Split(text, "\n")[0]), "# "), " Parity")
			key = "sample:" + strings.ToLower(strings.TrimSpace(heading))
			s, ok = samples[strings.TrimPrefix(key, "sample:")]
		}
		if !ok {
			problems = append(problems, fmt.Sprintf("%s: orphan inventory without a language release scope", entry.Name()))
			continue
		}
		if seen[key] {
			problems = append(problems, fmt.Sprintf("%s: duplicate inventory scope %s", entry.Name(), key))
		}
		seen[key] = true
		if tier := metaValue(text, "- Tier:"); tier != s.tier {
			problems = append(problems, fmt.Sprintf("%s: tier %q disagrees with languages.md tier %q", entry.Name(), tier, s.tier))
		}
	}
	for key, s := range scopes {
		if s.status == "released" && s.tier == "core" && !seen[key] {
			switch key {
			case "python", "typescript", "java":
				continue
			}
			problems = append(problems, fmt.Sprintf("%s: released Core scope %s has no split parity inventory", s.language, key))
		}
	}
	return inventories, problems
}

func validateSplitParity(text, specVersion string, symbols map[string]map[string]bool) []string {
	var problems []string
	report := func(format string, args ...any) { problems = append(problems, fmt.Sprintf(format, args...)) }
	validTier := map[string]bool{
		"core": true, "wire": true, "bridge": true, "sample": true,
	}
	validStatus := map[string]bool{
		"planned": true, "partial": true, "parity": true, "n/a": true,
	}
	validPhase := map[string]bool{
		"P1": true, "P2": true, "P3": true, "P4": true, "n/a": true,
	}
	tier := metaValue(text, "- Tier:")
	if !validTier[tier] {
		report("invalid tier %q", tier)
	}
	if got := metaValue(text, "- SPEC_VERSION:"); got != specVersion {
		report("SPEC_VERSION %q, want %q", got, specVersion)
	}
	seen := map[string]bool{}
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "|") {
			continue
		}
		cells := strings.Split(line, "|")
		if len(cells) > 2 && (strings.TrimSpace(cells[1]) == "Go symbol" || strings.HasPrefix(strings.TrimSpace(cells[1]), "---")) {
			continue
		}
		if len(cells) != 6 {
			report("malformed row %s", line)
			continue
		}
		goSymbol := strings.Trim(cells[1], " `")
		languageSymbol := strings.Trim(cells[2], " `")
		status := strings.TrimSpace(cells[3])
		phase := strings.TrimSpace(cells[4])
		if !validStatus[status] {
			report("%s invalid status %q", goSymbol, status)
		}
		if !validPhase[phase] {
			report("%s invalid phase %q", goSymbol, phase)
		}
		if (status == "parity" || status == "partial") && languageSymbol == "" {
			report("%s %s row without language symbol", goSymbol, status)
		}
		pkg, symbol, ok := splitGoSymbol(goSymbol, symbols)
		key := pkg + "." + symbol
		if seen[key] {
			report("duplicate symbol %s", goSymbol)
		}
		seen[key] = true
		if !ok || !symbols[pkg][symbol] {
			report("%s: Go symbol is not in current API snapshot", goSymbol)
		}
	}
	if len(seen) == 0 && tier == "core" {
		report("Core inventory has no symbol rows")
	}
	return problems
}

func splitGoSymbol(symbol string, symbols map[string]map[string]bool) (string, string, bool) {
	symbol = strings.TrimPrefix(symbol, "github.com/axisvela/praxo-core/v2/")
	if !strings.HasPrefix(symbol, "pkg/") {
		symbol = "pkg/" + symbol
	}
	pkg, name, ok := strings.Cut(symbol, ".")
	return pkg, name, ok && symbols[pkg] != nil && name != ""
}

func parseAPISymbols(api string) map[string]map[string]bool {
	out := map[string]map[string]bool{}
	decl := regexp.MustCompile(`^(?:type|func|const|var) ([A-Z][A-Za-z0-9_]*)\b`)
	method := regexp.MustCompile(`^func \((?:[A-Za-z_][A-Za-z0-9_]*\s+)?\*?([A-Z][A-Za-z0-9_]*)(?:\[[^\]]*\])?\) ([A-Z][A-Za-z0-9_]*)\(`)
	member := regexp.MustCompile(`^\s+([A-Z][A-Za-z0-9_]*)\b`)
	for pkg, section := range parseAPISections(api) {
		out[pkg] = map[string]bool{}
		owner, group := "", false
		for _, line := range strings.Split(section, "\n") {
			line = strings.TrimSuffix(line, "\r")
			if m := decl.FindStringSubmatch(line); m != nil {
				out[pkg][m[1]] = true
				if strings.HasPrefix(line, "type ") && strings.HasSuffix(line, "{") {
					owner = m[1]
				}
			}
			if m := method.FindStringSubmatch(line); m != nil {
				out[pkg][m[1]+"."+m[2]] = true
			}
			if line == "const (" || line == "var (" {
				group = true
			}
			if m := member.FindStringSubmatch(line); m != nil {
				if group {
					out[pkg][m[1]] = true
				} else if owner != "" {
					out[pkg][owner+"."+m[1]] = true
				}
			}
			if line == "}" || line == ")" {
				owner, group = "", false
			}
		}
	}
	return out
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
