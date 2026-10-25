package spec

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"time"

	agentstream "github.com/axisvela/praxo-core/v2/pkg/agent/stream"
	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool/jsonschema"
	"github.com/axisvela/praxo-core/v2/pkg/toolcall"
)

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
