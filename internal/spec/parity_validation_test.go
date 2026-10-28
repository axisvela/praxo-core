package spec

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const splitParityAPI = `### github.com/axisvela/praxo-core/v2/pkg/agent
Agent documentation mentions Phantom, but does not declare it.
type Agent struct {
	Model model.Model
}
func New(opts Options) (*Agent, error)
func (a *Agent) Run() error
type Options struct{}
type Alias = Agent
type Chain[A, B, C any] struct{}
func (c Chain[A, B, C]) Invoke() error
type Func[I, O any] func(I) O
func (f Func[I, O]) Invoke() error
type Runner interface {
	Run() error
}
const (
	Ready = 1
)
var (
	ErrStopped = errors.New("stopped")
)
### github.com/axisvela/praxo-core/v2/pkg/model
type Model interface{}
`

func TestValidateSplitParity(t *testing.T) {
	symbols := parseAPISymbols(splitParityAPI)
	const metadata = "- Tier: core\n- SPEC_VERSION: 0.2.0\n\n| Go symbol | SDK symbol | Status | Phase |\n| --- | --- | --- | --- |\n"
	tests := []struct {
		name, rows, want string
	}{
		{"idiomatic mapping", "| `agent.Agent` | `run_agent` | parity | P1 |", ""},
		{"alias", "| `agent.Alias` | `AgentOptions`, `run_agent` | partial | P1 |", ""},
		{"qualified package", "| `pkg/agent.Agent` | `Agent` | parity | P1 |", ""},
		{"module qualified", "| `github.com/axisvela/praxo-core/v2/pkg/agent.Agent` | `Agent` | parity | P1 |", ""},
		{"qualified method", "| `agent.Agent.Run` | `run` | parity | P1 |", ""},
		{"generic receiver", "| `agent.Chain.Invoke` | `invoke` | parity | P1 |", ""},
		{"generic function receiver", "| `agent.Func.Invoke` | `invoke` | parity | P1 |", ""},
		{"interface method", "| `agent.Runner.Run` | `run` | partial | P1 |", ""},
		{"qualified field", "| `pkg/agent.Agent.Model` | `model` | partial | P1 |", ""},
		{"constant", "| `agent.Ready` | `READY` | parity | P1 |", ""},
		{"variable", "| `agent.ErrStopped` | `StoppedError` | parity | P1 |", ""},
		{"planned P1", "| `agent.New` | | planned | P1 |", ""},
		{"partial P1", "| `agent.New` | `Options` | partial | P1 |", ""},
		{"unknown symbol", "| `agent.Unknown` | `Agent` | parity | P1 |", "Go symbol is not in current API snapshot"},
		{"documentation is not declaration", "| `agent.Phantom` | `Agent` | parity | P1 |", "Go symbol is not in current API snapshot"},
		{"reference is not declaration", "| `agent.Model` | `Model` | parity | P1 |", "Go symbol is not in current API snapshot"},
		{"unknown method", "| `agent.Agent.Stop` | `stop` | partial | P1 |", "Go symbol is not in current API snapshot"},
		{"wrong receiver", "| `agent.Options.Run` | `run` | parity | P1 |", "Go symbol is not in current API snapshot"},
		{"unknown package", "| `missing.Agent` | `Agent` | partial | P1 |", "Go symbol is not in current API snapshot"},
		{"empty Go mapping", "| `` | `Agent` | parity | P1 |", "Go symbol is not in current API snapshot"},
		{"empty parity mapping", "| `agent.Agent` | `` | parity | P1 |", "parity row without language symbol"},
		{"empty partial mapping", "| `agent.Agent` | | partial | P1 |", "partial row without language symbol"},
		{"duplicate", "| `agent.Agent` | `Agent` | parity | P1 |\n| `pkg/agent.Agent` | `run` | partial | P1 |", "duplicate symbol"},
		{"invalid status", "| `agent.Agent` | `Agent` | done | P1 |", "invalid status"},
		{"invalid phase", "| `agent.Agent` | `Agent` | partial | P0 |", "invalid phase"},
		{"malformed", "| `agent.Agent` | `Agent` | parity |", "malformed row"},
		{"empty inventory", "", "Core inventory has no symbol rows"},
	}
	for _, ending := range []string{"\n", "\r\n"} {
		for _, tt := range tests {
			t.Run(tt.name+map[string]string{"\n": "/LF", "\r\n": "/CRLF"}[ending], func(t *testing.T) {
				apiSymbols := parseAPISymbols(strings.ReplaceAll(splitParityAPI, "\n", ending))
				problems := validateSplitParity(strings.ReplaceAll(metadata+tt.rows, "\n", ending), "0.2.0", apiSymbols)
				checkParityProblems(t, problems, tt.want)
			})
		}
	}
	for _, tier := range []string{"bridge", "sample", "wire"} {
		t.Run(tier+" without Core rows", func(t *testing.T) {
			checkParityProblems(t, validateSplitParity(strings.Replace(metadata, "core", tier, 1), "0.2.0", symbols), "")
		})
	}
	checkParityProblems(t, validateSplitParity(strings.Replace(metadata, "core", "unknown", 1), "0.2.0", symbols), "invalid tier")
	checkParityProblems(t, validateSplitParity(metadata, "0.3.0", symbols), "SPEC_VERSION")
}

func TestDiscoverSplitParity(t *testing.T) {
	const matrix = `## Matrix
| Language | Tier | Status | Tag | Maturity | Notes |
| --- | --- | --- | --- | --- | --- |
| Go | Core (reference) | released | ` + "`v2.5.1`" + ` | reference | Reference |
| Python | Core | released | python/v0.2.0 | complete | Original |
| TypeScript | Core | released | typescript/v0.1.0 | complete | Original |
| Java | Core | released | java/v0.2.1 | complete | Original |
| New Language | Core | released | fresh/v0.1.0 | partial | New |
| Shell | Bridge | released | shell/v0.1.0 | complete | Bridge |
| Visual Basic | Sample (.NET) | released | fresh/v0.1.0 | sample | Host sample |
| Planned | Core | planned | none | planned | Not released |
## CI Coverage
`
	tests := []struct {
		name, matrix, want string
		files              map[string]string
	}{
		{"new released Core", matrix, "released Core scope fresh has no split parity inventory", nil},
		{"automatic discovery", matrix, "", map[string]string{"fresh.md": "- Tier: core"}},
		{"orphan", matrix, "orphan inventory", map[string]string{"fresh.md": "- Tier: core", "ghost.md": "- Tier: core"}},
		{"tier mismatch", matrix, "disagrees with languages.md", map[string]string{"fresh.md": "- Tier: wire"}},
		{"bridge and sample", matrix, "", map[string]string{"fresh.md": "- Tier: core", "bridge-shell.md": "- Tier: bridge", "vbnet.md": "# Visual Basic Parity\n- Tier: sample"}},
		{"CRLF bridge and sample", strings.ReplaceAll(matrix, "\n", "\r\n"), "", map[string]string{"fresh.md": "- Tier: core\r\n", "bridge-shell.md": "- Tier: bridge\r\n", "vbnet.md": "# Visual Basic Parity\r\n- Tier: sample\r\n"}},
		{"duplicate scope", matrix, "duplicate inventory scope", map[string]string{"fresh.md": "- Tier: core", "bridge-fresh.md": "- Tier: core"}},
		{"no scope tag", strings.Replace(matrix, "fresh/v0.1.0", "none", 1), "no release-tag scope", nil},
		{"empty tier", strings.Replace(matrix, "New Language | Core", "New Language |", 1), "empty language tier", nil},
		{"empty registry", "", "no language release scopes", nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			root := t.TempDir()
			dir := filepath.Join(root, "spec", "parity")
			if err := os.MkdirAll(dir, 0o755); err != nil {
				t.Fatal(err)
			}
			writeParityFixture(t, filepath.Join(root, "spec", "languages.md"), tt.matrix)
			writeParityFixture(t, filepath.Join(dir, "README.md"), "Not an inventory")
			for name, text := range tt.files {
				writeParityFixture(t, filepath.Join(dir, name), text)
			}
			inventories, problems := discoverSplitParity(root)
			checkParityProblems(t, problems, tt.want)
			if len(inventories) != len(tt.files) {
				t.Fatalf("discovered %d inventories, want %d", len(inventories), len(tt.files))
			}
		})
	}
}

func writeParityFixture(t *testing.T, path, text string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
}

func checkParityProblems(t *testing.T, problems []string, want string) {
	t.Helper()
	if want == "" {
		if len(problems) != 0 {
			t.Fatalf("unexpected problems: %v", problems)
		}
	} else if !strings.Contains(strings.Join(problems, "\n"), want) {
		t.Fatalf("problems %v do not contain %q", problems, want)
	}
}
