package agent

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/pkg/event"
	"github.com/axisvela/praxo-core/pkg/memory"
	"github.com/axisvela/praxo-core/pkg/model"
	"github.com/axisvela/praxo-core/pkg/policy"
	"github.com/axisvela/praxo-core/pkg/tool"
)

type fakeModel struct {
	calls int
}

func (f *fakeModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	f.calls++
	if f.calls == 1 {
		return model.Response{
			Message: model.Message{
				Role: model.RoleAssistant,
				ToolCalls: []model.ToolCall{{
					ID: "call-1", Name: "echo", Arguments: map[string]any{"value": "hi"},
				}},
			},
			Usage: model.Usage{InputTokens: 10, OutputTokens: 2},
		}, nil
	}
	return model.Response{
		Message: model.Message{Role: model.RoleAssistant, Content: "final"},
		Usage:   model.Usage{InputTokens: 4, OutputTokens: 1},
	}, nil
}

type echoTool struct{ calls int }

func (e *echoTool) Name() string        { return "echo" }
func (e *echoTool) Description() string { return "echo a value" }
func (e *echoTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	e.calls++
	return args["value"], nil
}

type denyPolicy struct{}

func (denyPolicy) Authorize(context.Context, policy.Action) (policy.Decision, error) {
	return policy.Decision{Allowed: false, Reason: "test deny"}, nil
}

type allowPolicy struct{}

func (allowPolicy) Authorize(context.Context, policy.Action) (policy.Decision, error) {
	return policy.Decision{Allowed: true}, nil
}

func TestRunExecutesToolAndCompletes(t *testing.T) {
	tools := tool.NewRegistry()
	echo := &echoTool{}
	tools.Register(echo)
	var events []string

	ag := &Agent{
		Model:  &fakeModel{},
		Tools:  tools,
		Policy: allowPolicy{},
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			events = append(events, e.Type)
			return nil
		}),
		MaxSteps: 4,
	}
	result, err := ag.Run(context.Background(), Session{ID: "s1", TenantID: "acme"}, "do it")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "final" || result.Steps != 2 {
		t.Fatalf("result = %+v", result)
	}
	if echo.calls != 1 {
		t.Fatalf("tool calls = %d, want 1", echo.calls)
	}
	if result.Usage.InputTokens != 14 || result.Usage.OutputTokens != 3 {
		t.Fatalf("usage = %+v", result.Usage)
	}
	if len(events) < 3 || events[0] != "run.started" || events[len(events)-1] != "run.completed" {
		t.Fatalf("events = %+v", events)
	}
}

func TestRunFailsClosedOnPolicyDenial(t *testing.T) {
	ag := &Agent{Model: &fakeModel{}, Policy: denyPolicy{}}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err == nil {
		t.Fatal("expected policy denial")
	}
}

func TestRunRequiresModel(t *testing.T) {
	ag := &Agent{}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err == nil {
		t.Fatal("expected an error")
	}
}

type flakyModel struct {
	failures int
	calls    int
	err      error
}

func (f *flakyModel) Generate(context.Context, model.Request) (model.Response, error) {
	f.calls++
	if f.calls <= f.failures {
		return model.Response{}, f.err
	}
	return model.Response{
		Message: model.Message{Role: model.RoleAssistant, Content: "recovered"},
	}, nil
}

func TestRetryPolicyRetriesTransientErrors(t *testing.T) {
	m := &flakyModel{failures: 2, err: errors.New("transient")}
	ag := &Agent{Model: m, Retry: RetryPolicy{Attempts: 3}}
	result, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it")
	if err != nil {
		t.Fatal(err)
	}
	if m.calls != 3 || result.Output != "recovered" {
		t.Fatalf("calls=%d result=%+v", m.calls, result)
	}
}

func TestRetryPolicyHonorsShouldRetry(t *testing.T) {
	sentinel := errors.New("permanent")
	m := &flakyModel{failures: 1, err: sentinel}
	ag := &Agent{
		Model: m,
		Retry: RetryPolicy{
			Attempts:    3,
			ShouldRetry: func(err error) bool { return !errors.Is(err, sentinel) },
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v", err)
	}
	if m.calls != 1 {
		t.Fatalf("calls = %d, want 1", m.calls)
	}
}

type streamingModel struct {
	deltas []string
}

func (s *streamingModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "hello"}}, nil
}

func (s *streamingModel) GenerateStream(_ context.Context, _ model.Request, onDelta func(string)) (model.Response, error) {
	for _, d := range s.deltas {
		onDelta(d)
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "hello"}}, nil
}

func TestRunStreamsDeltas(t *testing.T) {
	m := &streamingModel{deltas: []string{"he", "llo"}}
	var got []string
	ag := &Agent{Model: m, OnDelta: func(d string) { got = append(got, d) }}
	result, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "hello" || len(got) != 2 || got[0] != "he" || got[1] != "llo" {
		t.Fatalf("result=%+v deltas=%v", result, got)
	}
}

type simpleModel struct{}

func (simpleModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "ok"}}, nil
}

func TestRunInvokesHooksInOrder(t *testing.T) {
	var order []string
	ag := &Agent{
		Model: simpleModel{},
		Hooks: Hooks{
			OnRunStart: func(context.Context, string, Session) error {
				order = append(order, "start")
				return nil
			},
			OnStep: func(context.Context, string, int, []model.Message) error {
				order = append(order, "step")
				return nil
			},
			OnModelCall: func(context.Context, string, model.Request) error {
				order = append(order, "model.call")
				return nil
			},
			OnModelResult: func(context.Context, string, model.Response) error {
				order = append(order, "model.result")
				return nil
			},
			OnRunComplete: func(context.Context, *Result) error {
				order = append(order, "complete")
				return nil
			},
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	want := []string{"start", "step", "model.call", "model.result", "complete"}
	if len(order) != len(want) {
		t.Fatalf("order = %v", order)
	}
	for i := range want {
		if order[i] != want[i] {
			t.Fatalf("order = %v, want %v", order, want)
		}
	}
}

func TestRunDoesNotMutateMaxSteps(t *testing.T) {
	ag := &Agent{Model: simpleModel{}}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if ag.MaxSteps != 0 {
		t.Fatalf("MaxSteps = %d, want 0", ag.MaxSteps)
	}
}

type multiCallModel struct {
	calls int
}

func (m *multiCallModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{
				{ID: "1", Name: "barrier"},
				{ID: "2", Name: "barrier"},
			},
		}}, nil
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "done"}}, nil
}

type barrierTool struct {
	started chan struct{}
	release chan struct{}
}

func (b *barrierTool) Name() string        { return "barrier" }
func (b *barrierTool) Description() string { return "waits for release" }
func (b *barrierTool) Invoke(ctx context.Context, _ map[string]any) (any, error) {
	b.started <- struct{}{}
	select {
	case <-b.release:
		return "ok", nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func TestRunInvokesToolsInParallel(t *testing.T) {
	barrier := &barrierTool{started: make(chan struct{}, 2), release: make(chan struct{})}
	closed := false
	defer func() {
		if !closed {
			close(barrier.release)
		}
	}()

	tools := tool.NewRegistry()
	tools.Register(barrier)
	ag := &Agent{Model: &multiCallModel{}, Tools: tools, MaxParallelTools: 2}

	done := make(chan error, 1)
	go func() {
		_, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it")
		done <- err
	}()

	for i := 0; i < 2; i++ {
		select {
		case <-barrier.started:
		case <-time.After(2 * time.Second):
			t.Fatal("tools did not start in parallel")
		}
	}
	close(barrier.release)
	closed = true
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

type panicTool struct{}

func (panicTool) Name() string        { return "panic" }
func (panicTool) Description() string { return "panics" }
func (panicTool) Invoke(context.Context, map[string]any) (any, error) {
	panic("boom")
}

type panicModel struct{}

func (panicModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{
		Role:      model.RoleAssistant,
		ToolCalls: []model.ToolCall{{ID: "1", Name: "panic"}},
	}}, nil
}

func TestToolPanicBecomesError(t *testing.T) {
	tools := tool.NewRegistry()
	tools.Register(panicTool{})
	ag := &Agent{Model: panicModel{}, Tools: tools}
	_, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it")
	if err == nil || !strings.Contains(err.Error(), "panicked") {
		t.Fatalf("err = %v", err)
	}
}

type requestModel struct {
	req model.Request
}

func (m *requestModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.req = req
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "ok"}}, nil
}

func TestToolChoiceAndAllowedTools(t *testing.T) {
	tools := tool.NewRegistry()
	tools.Register(&echoTool{})
	tools.Register(&barrierTool{started: make(chan struct{}, 1), release: make(chan struct{})})
	m := &requestModel{}
	ag := &Agent{
		Model:        m,
		Tools:        tools,
		ToolChoice:   model.ToolChoiceRequired,
		AllowedTools: []string{"echo"},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if m.req.ToolChoice != model.ToolChoiceRequired {
		t.Fatalf("tool choice = %q", m.req.ToolChoice)
	}
	if len(m.req.Tools) != 1 || m.req.Tools[0].Name != "echo" {
		t.Fatalf("tools = %+v", m.req.Tools)
	}
}

type toolCallModel struct {
	name  string
	calls int
}

func (m *toolCallModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{
			Role:      model.RoleAssistant,
			ToolCalls: []model.ToolCall{{ID: "1", Name: m.name}},
		}}, nil
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "done"}}, nil
}

func TestAllowedToolsBlocksInvocation(t *testing.T) {
	tools := tool.NewRegistry()
	tools.Register(&echoTool{})
	ag := &Agent{
		Model:        &toolCallModel{name: "echo"},
		Tools:        tools,
		AllowedTools: []string{"other"},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err == nil {
		t.Fatal("expected a not-allowed error")
	}
}

type tokenModel struct{ calls int }

func (m *tokenModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	return model.Response{
		Message: model.Message{Role: model.RoleAssistant, Content: "ok"},
		Usage:   model.Usage{InputTokens: 100, OutputTokens: 50},
	}, nil
}

func TestMaxTokensStopsRun(t *testing.T) {
	m := &tokenModel{}
	ag := &Agent{Model: m, MaxTokens: 100}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); !errors.Is(err, ErrMaxTokens) {
		t.Fatalf("err = %v", err)
	}
	if m.calls != 1 {
		t.Fatalf("calls = %d, want 1", m.calls)
	}
}

type fakeMemory struct {
	records []memory.Record
	puts    []memory.Record
}

func (f *fakeMemory) Put(_ context.Context, _ string, record memory.Record) error {
	f.puts = append(f.puts, record)
	return nil
}

func (f *fakeMemory) Search(context.Context, string, string, int) ([]memory.Record, error) {
	return f.records, nil
}

func TestRecallInjectsMemory(t *testing.T) {
	mem := &fakeMemory{records: []memory.Record{{Frame: memory.FrameExperience, Content: "use tabs"}}}
	m := &requestModel{}
	ag := &Agent{Model: m, Memory: mem, Recall: true}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "style?"); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, msg := range m.req.Messages {
		if msg.Role == model.RoleSystem && strings.Contains(msg.Content, "use tabs") {
			found = true
		}
	}
	if !found {
		t.Fatalf("messages = %+v", m.req.Messages)
	}
}

func TestMemoryWriteHook(t *testing.T) {
	mem := &fakeMemory{}
	var written []memory.Record
	ag := &Agent{
		Model:  simpleModel{},
		Memory: mem,
		Hooks: Hooks{
			OnMemoryWrite: func(_ context.Context, _ string, record memory.Record) error {
				written = append(written, record)
				return nil
			},
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if len(written) != 1 || len(mem.puts) != 1 {
		t.Fatalf("written=%d puts=%d", len(written), len(mem.puts))
	}
}
