package spec

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	agentstream "github.com/axisvela/praxo-core/v2/pkg/agent/stream"
	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/tool/jsonschema"
	"github.com/axisvela/praxo-core/v2/pkg/toolcall"
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

func TestWireReferences(t *testing.T) {
	root := repoRoot(t)
	version := strings.TrimSpace(string(readFile(t, filepath.Join(root, vectorDir, "SPEC_VERSION"))))

	var events struct {
		SpecVersion string `json:"specVersion"`
		EventTypes  []struct {
			Type string `json:"type"`
		} `json:"eventTypes"`
		StreamKinds []struct {
			Kind string `json:"kind"`
		} `json:"streamKinds"`
	}
	readJSONFile(t, filepath.Join(root, vectorDir, "wire", "events.json"), &events)

	var errs struct {
		SpecVersion string `json:"specVersion"`
		Sentinels   []struct {
			Code string `json:"code"`
		} `json:"sentinels"`
		PluginCallErrorCodes []string `json:"pluginCallErrorCodes"`
	}
	readJSONFile(t, filepath.Join(root, vectorDir, "wire", "errors.json"), &errs)

	if events.SpecVersion != version {
		t.Errorf("events.json specVersion %q, want %q", events.SpecVersion, version)
	}
	if errs.SpecVersion != version {
		t.Errorf("errors.json specVersion %q, want %q", errs.SpecVersion, version)
	}

	eventTypes := map[string]bool{}
	for _, e := range events.EventTypes {
		eventTypes[e.Type] = true
	}
	streamKinds := map[string]bool{}
	for _, k := range events.StreamKinds {
		streamKinds[k.Kind] = true
	}
	codes := map[string]bool{}
	for _, s := range errs.Sentinels {
		codes[s.Code] = true
	}
	for _, c := range errs.PluginCallErrorCodes {
		codes[c] = true
	}

	for _, f := range loadVectorFiles(t, root) {
		for _, v := range f.Vectors {
			var input, expect map[string]any
			if err := json.Unmarshal(v.Input, &input); err != nil {
				t.Errorf("%s: input: %v", v.ID, err)
				continue
			}
			if err := json.Unmarshal(v.Expect, &expect); err != nil {
				t.Errorf("%s: expect: %v", v.ID, err)
				continue
			}
			checkWireRefs(t, v.ID, input, eventTypes, streamKinds, codes)
			checkWireRefs(t, v.ID, expect, eventTypes, streamKinds, codes)
		}
	}
}

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

func runVector(group string, v vectorCase) error {
	switch group {
	case "toolcall":
		return runToolcall(v)
	case "jsonschema":
		return runJSONSchema(v)
	case "plugin":
		return runPlugin(v)
	case "memory":
		return runMemory(v)
	case "event":
		return runEvent(v)
	case "stream":
		return runStream(v)
	case "checkpoint":
		return runCheckpoint(v)
	case "policy":
		return runPolicy(v)
	case "agent-loop":
		return runAgentLoop(v)
	default:
		return fmt.Errorf("no runner for group %q", group)
	}
}

func runToolcall(v vectorCase) error {
	var in struct {
		Operation string `json:"operation"`
		Content   string `json:"content"`
	}
	var exp struct {
		Nil   bool           `json:"nil"`
		Name  string         `json:"name"`
		Input map[string]any `json:"input"`
		Text  string         `json:"text"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	if in.Operation == "strip" {
		if got := toolcall.StripToolCallMarkup(in.Content); got != exp.Text {
			return fmt.Errorf("strip: got %q want %q", got, exp.Text)
		}
		return nil
	}
	call := toolcall.ParseToolCall(in.Content)
	if exp.Nil {
		if call != nil {
			return fmt.Errorf("expected nil, got %+v", call)
		}
		return nil
	}
	if call == nil {
		return errors.New("expected a tool call, got nil")
	}
	if call.Name != exp.Name {
		return fmt.Errorf("name: got %q want %q", call.Name, exp.Name)
	}
	if !reflect.DeepEqual(call.Input, exp.Input) {
		return fmt.Errorf("input: got %#v want %#v", call.Input, exp.Input)
	}
	return nil
}

func runJSONSchema(v vectorCase) error {
	var in struct {
		Schema jsonschema.Schema `json:"schema"`
		Data   any               `json:"data"`
	}
	var exp struct {
		Valid      bool     `json:"valid"`
		ErrorPaths []string `json:"errorPaths"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	errs := in.Schema.Validate(in.Data)
	got := make([]string, 0, len(errs))
	for _, e := range errs {
		got = append(got, e.Path)
	}
	sort.Strings(got)
	want := append([]string(nil), exp.ErrorPaths...)
	sort.Strings(want)
	if len(got) == 0 {
		got = nil
	}
	if len(want) == 0 {
		want = nil
	}
	if exp.Valid != (len(errs) == 0) {
		return fmt.Errorf("valid: got %v want %v (errors %v)", len(errs) == 0, exp.Valid, errs)
	}
	if !reflect.DeepEqual(got, want) {
		return fmt.Errorf("errorPaths: got %v want %v", got, want)
	}
	return nil
}

func runPlugin(v vectorCase) error {
	var in struct {
		Raw      string         `json:"raw"`
		Manifest map[string]any `json:"manifest"`
	}
	var exp struct {
		Valid bool   `json:"valid"`
		ID    string `json:"id"`
		Kind  string `json:"kind"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	raw := []byte(in.Raw)
	if in.Raw == "" {
		var err error
		raw, err = json.Marshal(in.Manifest)
		if err != nil {
			return err
		}
	}
	m, err := plugin.ParseManifest(raw)
	if !exp.Valid {
		if err == nil {
			return errors.New("expected an invalid manifest")
		}
		return nil
	}
	if err != nil {
		return fmt.Errorf("expected a valid manifest: %w", err)
	}
	if exp.ID != "" && m.ID != exp.ID {
		return fmt.Errorf("id: got %q want %q", m.ID, exp.ID)
	}
	if exp.Kind != "" && string(m.Kind) != exp.Kind {
		return fmt.Errorf("kind: got %q want %q", m.Kind, exp.Kind)
	}
	return nil
}

func runMemory(v vectorCase) error {
	type put struct {
		Session string        `json:"session"`
		Record  memory.Record `json:"record"`
	}
	var in struct {
		Puts    []put  `json:"puts"`
		Session string `json:"session"`
		Query   string `json:"query"`
		Limit   int    `json:"limit"`
	}
	var exp struct {
		IDs      []string `json:"ids"`
		Contents []string `json:"contents"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	ctx := context.Background()
	store := memory.NewMemoryStore()
	for _, p := range in.Puts {
		if err := store.Put(ctx, p.Session, p.Record); err != nil {
			return err
		}
	}
	got, err := store.Search(ctx, in.Session, in.Query, in.Limit)
	if err != nil {
		return err
	}
	var ids, contents []string
	for _, r := range got {
		ids = append(ids, r.ID)
		contents = append(contents, r.Content)
	}
	if len(ids) == 0 {
		ids = nil
	}
	if len(contents) == 0 {
		contents = nil
	}
	if !reflect.DeepEqual(ids, exp.IDs) {
		return fmt.Errorf("ids: got %v want %v", ids, exp.IDs)
	}
	if !reflect.DeepEqual(contents, exp.Contents) {
		return fmt.Errorf("contents: got %v want %v", contents, exp.Contents)
	}
	return nil
}

type recordingSink struct {
	types []string
}

func (r *recordingSink) Emit(_ context.Context, e event.Event) error {
	r.types = append(r.types, e.Type)
	return nil
}

func runEvent(v vectorCase) error {
	var in struct {
		Sink           string   `json:"sink"`
		SinkCount      int      `json:"sinkCount"`
		Events         []string `json:"events"`
		PredicateTypes []string `json:"predicateTypes"`
	}
	var exp struct {
		Delivered []string   `json:"delivered"`
		PerSink   [][]string `json:"perSink"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	ctx := context.Background()
	events := make([]event.Event, 0, len(in.Events))
	for _, typ := range in.Events {
		events = append(events, event.Event{Type: typ, SessionID: "s1", At: time.Unix(0, 0).UTC()})
	}

	switch in.Sink {
	case "", "filter":
		rec := &recordingSink{}
		var pred event.Predicate
		if in.PredicateTypes != nil {
			allowed := map[string]bool{}
			for _, typ := range in.PredicateTypes {
				allowed[typ] = true
			}
			pred = func(e event.Event) bool { return allowed[e.Type] }
		}
		sink := event.FilterSink{Sink: rec, Predicate: pred}
		for _, e := range events {
			if err := sink.Emit(ctx, e); err != nil {
				return err
			}
		}
		got := rec.types
		if len(got) == 0 {
			got = nil
		}
		if !reflect.DeepEqual(got, exp.Delivered) {
			return fmt.Errorf("delivered: got %v want %v", got, exp.Delivered)
		}
		return nil
	case "multi":
		n := in.SinkCount
		if n <= 0 {
			n = 1
		}
		recs := make([]*recordingSink, n)
		sinks := make([]event.Sink, n)
		for i := range recs {
			recs[i] = &recordingSink{}
			sinks[i] = recs[i]
		}
		multi := event.MultiSink(sinks)
		for _, e := range events {
			if err := multi.Emit(ctx, e); err != nil {
				return err
			}
		}
		got := make([][]string, n)
		for i, rec := range recs {
			got[i] = rec.types
			if len(got[i]) == 0 {
				got[i] = nil
			}
		}
		if !reflect.DeepEqual(got, exp.PerSink) {
			return fmt.Errorf("perSink: got %v want %v", got, exp.PerSink)
		}
		return nil
	default:
		return fmt.Errorf("unknown sink %q", in.Sink)
	}
}

func runStream(v vectorCase) error {
	var exp struct {
		Kinds []string `json:"kinds"`
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	got := []string{
		string(agentstream.StreamValues),
		string(agentstream.StreamUpdates),
		string(agentstream.StreamMessages),
		string(agentstream.StreamTasks),
		string(agentstream.StreamDebug),
		string(agentstream.StreamCheckpoint),
	}
	if !reflect.DeepEqual(got, exp.Kinds) {
		return fmt.Errorf("kinds: got %v want %v", got, exp.Kinds)
	}
	return nil
}

func runCheckpoint(v vectorCase) error {
	var in struct {
		Operation  string   `json:"operation"`
		Registered []string `json:"registered"`
		Type       string   `json:"type"`
		Value      any      `json:"value"`
	}
	var exp struct {
		Value     any    `json:"value"`
		ErrorCode string `json:"errorCode"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	allow := checkpoint.NewAllowlist()
	for _, name := range in.Registered {
		if err := allow.Register(name, func() any { return &map[string]any{} }); err != nil {
			return err
		}
	}
	if in.Operation == "" {
		in.Operation = "roundtrip"
	}
	switch in.Operation {
	case "roundtrip":
		data, err := allow.Marshal(in.Type, in.Value)
		if err != nil {
			return err
		}
		got, err := allow.Unmarshal(data)
		if err != nil {
			return err
		}
		p, ok := got.(*map[string]any)
		if !ok {
			return fmt.Errorf("unexpected payload type %T", got)
		}
		if !reflect.DeepEqual(*p, exp.Value) {
			return fmt.Errorf("value: got %#v want %#v", *p, exp.Value)
		}
		return nil
	case "marshal":
		_, err := allow.Marshal(in.Type, in.Value)
		return checkpointError(err, exp.ErrorCode)
	case "unmarshal":
		raw, err := json.Marshal(map[string]any{"type": in.Type, "data": in.Value})
		if err != nil {
			return err
		}
		_, err = allow.Unmarshal(raw)
		return checkpointError(err, exp.ErrorCode)
	default:
		return fmt.Errorf("unknown checkpoint operation %q", in.Operation)
	}
}

func checkpointError(err error, code string) error {
	if code == "" {
		return err
	}
	if !errors.Is(err, checkpoint.ErrTypeNotAllowed) {
		return fmt.Errorf("expected %s, got %v", code, err)
	}
	return nil
}

func runPolicy(v vectorCase) error {
	var in struct {
		Grants []struct {
			Root   string `json:"root"`
			Access string `json:"access"`
		} `json:"grants"`
		MakeDirs []string `json:"makeDirs"`
		Target   string   `json:"target"`
		Need     string   `json:"need"`
	}
	var exp struct {
		Allowed bool `json:"allowed"`
		Error   bool `json:"error"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	base, err := os.MkdirTemp("", "praxo-spec-policy-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(base)

	for _, d := range in.MakeDirs {
		if err := os.MkdirAll(filepath.Join(base, d), 0o755); err != nil {
			return err
		}
	}
	grants := make([]policy.PathGrant, 0, len(in.Grants))
	for _, g := range in.Grants {
		root := filepath.Join(base, g.Root)
		if err := os.MkdirAll(root, 0o755); err != nil {
			return err
		}
		grants = append(grants, policy.PathGrant{Root: root, Access: policy.PathAccess(g.Access)})
	}
	checker, err := policy.NewPathChecker(grants)
	if err != nil {
		if exp.Error {
			return nil
		}
		return err
	}
	need := in.Need
	if need == "" {
		need = "read"
	}
	d, err := checker.Check(filepath.Join(base, in.Target), policy.PathAccess(need))
	if exp.Error {
		if err == nil {
			return errors.New("expected a policy error")
		}
		return nil
	}
	if err != nil {
		return err
	}
	if d.Allowed != exp.Allowed {
		return fmt.Errorf("allowed: got %v want %v (%s)", d.Allowed, exp.Allowed, d.Reason)
	}
	return nil
}

type scriptedModel struct {
	steps []agentScriptStep
	next  int
}

type agentScriptStep struct {
	Content      string           `json:"content"`
	ToolCalls    []model.ToolCall `json:"toolCalls"`
	InputTokens  int64            `json:"inputTokens"`
	OutputTokens int64            `json:"outputTokens"`
}

func (m *scriptedModel) Generate(_ context.Context, _ model.Request) (model.Response, error) {
	if m.next >= len(m.steps) {
		return model.Response{}, errors.New("spec: script exhausted")
	}
	s := m.steps[m.next]
	m.next++
	return model.Response{
		Message: model.Message{Role: model.RoleAssistant, Content: s.Content, ToolCalls: s.ToolCalls},
		Usage:   model.Usage{InputTokens: s.InputTokens, OutputTokens: s.OutputTokens},
	}, nil
}

type specTool struct {
	name  string
	desc  string
	calls *int
}

func (t *specTool) Name() string        { return t.name }
func (t *specTool) Description() string { return t.desc }

func (t *specTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls = *t.calls + 1
	return args, nil
}

func runAgentLoop(v vectorCase) error {
	type toolDef struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	var in struct {
		Prompt    string            `json:"prompt"`
		Script    []agentScriptStep `json:"script"`
		Tools     []toolDef         `json:"tools"`
		MaxSteps  int               `json:"maxSteps"`
		MaxTokens int64             `json:"maxTokens"`
	}
	var exp struct {
		Output          string   `json:"output"`
		Steps           int      `json:"steps"`
		Events          []string `json:"events"`
		ToolInvocations int      `json:"toolInvocations"`
		Error           bool     `json:"error"`
		ErrorCode       string   `json:"errorCode"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}

	calls := 0
	registry := tool.NewRegistry()
	for _, def := range in.Tools {
		registry.Register(&specTool{name: def.Name, desc: def.Description, calls: &calls})
	}
	sink := &recordingSink{}
	ag, err := agent.New(agent.Options{
		Model:     &scriptedModel{steps: in.Script},
		Tools:     registry,
		Events:    sink,
		MaxSteps:  in.MaxSteps,
		MaxTokens: in.MaxTokens,
	})
	if err != nil {
		return err
	}
	result, err := ag.Run(context.Background(), agent.Session{ID: "s1"}, in.Prompt)

	if exp.Error {
		if err == nil {
			return errors.New("expected an error")
		}
		if exp.ErrorCode != "" {
			switch exp.ErrorCode {
			case "AGENT_MAX_STEPS":
				if !errors.Is(err, agent.ErrMaxSteps) {
					return fmt.Errorf("error: got %v, want ErrMaxSteps", err)
				}
			case "AGENT_MAX_TOKENS":
				if !errors.Is(err, agent.ErrMaxTokens) {
					return fmt.Errorf("error: got %v, want ErrMaxTokens", err)
				}
			default:
				return fmt.Errorf("unknown error code %q", exp.ErrorCode)
			}
		}
	} else if err != nil {
		return err
	}

	if exp.Output != "" || result != nil {
		gotOutput := ""
		gotSteps := 0
		if result != nil {
			gotOutput = result.Output
			gotSteps = result.Steps
		}
		if gotOutput != exp.Output {
			return fmt.Errorf("output: got %q want %q", gotOutput, exp.Output)
		}
		if gotSteps != exp.Steps {
			return fmt.Errorf("steps: got %d want %d", gotSteps, exp.Steps)
		}
	}
	if calls != exp.ToolInvocations {
		return fmt.Errorf("tool invocations: got %d want %d", calls, exp.ToolInvocations)
	}
	gotEvents := sink.types
	if len(gotEvents) == 0 {
		gotEvents = nil
	}
	if !reflect.DeepEqual(gotEvents, exp.Events) {
		return fmt.Errorf("events: got %v want %v", gotEvents, exp.Events)
	}
	return nil
}

func checkWireRefs(t *testing.T, id string, m map[string]any, events, kinds, codes map[string]bool) {
	t.Helper()
	for key, value := range m {
		switch key {
		case "errorCode":
			s, ok := value.(string)
			if !ok {
				t.Errorf("%s: errorCode is not a string", id)
				continue
			}
			if !codes[s] {
				t.Errorf("%s: unknown error code %q", id, s)
			}
		case "events", "delivered", "predicateTypes":
			for _, item := range stringSlice(value) {
				if !events[item] {
					t.Errorf("%s: unknown event type %q", id, item)
				}
			}
		case "kinds":
			for _, item := range stringSlice(value) {
				if !kinds[item] {
					t.Errorf("%s: unknown stream kind %q", id, item)
				}
			}
		case "perSink":
			if list, ok := value.([]any); ok {
				for _, inner := range list {
					for _, item := range stringSlice(inner) {
						if !events[item] {
							t.Errorf("%s: unknown event type %q", id, item)
						}
					}
				}
			}
		}
	}
}

func stringSlice(v any) []string {
	list, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(list))
	for _, item := range list {
		if s, ok := item.(string); ok {
			out = append(out, s)
		}
	}
	return out
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
