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

func TestNewRequiresModel(t *testing.T) {
	if _, err := New(Options{}); err == nil {
		t.Fatal("expected a model error")
	}
}

func TestNewAppliesOptions(t *testing.T) {
	ag, err := New(Options{Model: simpleModel{}, SystemPrompt: "be terse", MaxSteps: 3})
	if err != nil {
		t.Fatal(err)
	}
	if ag.SystemPrompt != "be terse" || ag.MaxSteps != 3 {
		t.Fatalf("agent = %+v", ag)
	}
}

func TestSystemPromptPrepended(t *testing.T) {
	m := &requestModel{}
	ag, err := New(Options{Model: m, SystemPrompt: "be terse"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if len(m.req.Messages) == 0 || m.req.Messages[0].Role != model.RoleSystem || m.req.Messages[0].Content != "be terse" {
		t.Fatalf("messages = %+v", m.req.Messages)
	}
}

type fakeSkills struct{ skills []Skill }

func (f fakeSkills) Skills(context.Context, string) ([]Skill, error) { return f.skills, nil }

func TestSkillsInjected(t *testing.T) {
	m := &requestModel{}
	ag, err := New(Options{
		Model:  m,
		Skills: fakeSkills{skills: []Skill{{Name: "go", Content: "use gofmt"}}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "format"); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, msg := range m.req.Messages {
		if msg.Role == model.RoleSystem && strings.Contains(msg.Content, "use gofmt") {
			found = true
		}
	}
	if !found {
		t.Fatalf("messages = %+v", m.req.Messages)
	}
}

func TestResponseFormatForwarded(t *testing.T) {
	m := &requestModel{}
	format := &model.ResponseFormat{Name: "answer", Schema: map[string]any{"type": "object"}}
	ag, err := New(Options{Model: m, ResponseFormat: format})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if m.req.ResponseFormat == nil || m.req.ResponseFormat.Name != "answer" {
		t.Fatalf("response format = %+v", m.req.ResponseFormat)
	}
}

func TestInterruptApprovesTool(t *testing.T) {
	tools := tool.NewRegistry()
	echo := &echoTool{}
	tools.Register(echo)
	ag, err := New(Options{
		Model:       &toolCallModel{name: "echo"},
		Tools:       tools,
		InterruptOn: map[string]bool{"echo": true},
		OnInterrupt: func(context.Context, Interrupt) (bool, error) { return true, nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if echo.calls != 1 {
		t.Fatalf("calls = %d, want 1", echo.calls)
	}
}

func TestInterruptDeniesTool(t *testing.T) {
	tools := tool.NewRegistry()
	echo := &echoTool{}
	tools.Register(echo)
	ag, err := New(Options{
		Model:       &toolCallModel{name: "echo"},
		Tools:       tools,
		InterruptOn: map[string]bool{"echo": true},
		OnInterrupt: func(context.Context, Interrupt) (bool, error) { return false, nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	_, err = ag.Run(context.Background(), Session{ID: "s1"}, "do it")
	if !errors.Is(err, ErrApprovalDenied) {
		t.Fatalf("err = %v", err)
	}
	if echo.calls != 0 {
		t.Fatalf("calls = %d, want 0", echo.calls)
	}
}

func TestInterruptRequiresHandler(t *testing.T) {
	tools := tool.NewRegistry()
	tools.Register(&echoTool{})
	ag, err := New(Options{
		Model:       &toolCallModel{name: "echo"},
		Tools:       tools,
		InterruptOn: map[string]bool{"echo": true},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); !errors.Is(err, ErrInterruptUnhandled) {
		t.Fatalf("err = %v", err)
	}
}

func TestRunContextVisibleToHooks(t *testing.T) {
	var seen RunContext
	ag, err := New(Options{
		Model: simpleModel{},
		Hooks: Hooks{OnStep: func(ctx context.Context, _ string, _ int, _ []model.Message) error {
			seen = RunContextFrom(ctx)
			return nil
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.RunWithContext(context.Background(), Session{ID: "s1"}, "do it", RunContext{"user": "u1"}); err != nil {
		t.Fatal(err)
	}
	if seen["user"] != "u1" {
		t.Fatalf("run context = %+v", seen)
	}
}

func TestProfileFillsDefaults(t *testing.T) {
	ag, err := New(Options{
		Model:   simpleModel{},
		Profile: &Profile{SystemPrompt: "profile", MaxSteps: 5, MaxTokens: 100},
	})
	if err != nil {
		t.Fatal(err)
	}
	if ag.SystemPrompt != "profile" || ag.MaxSteps != 5 || ag.MaxTokens != 100 {
		t.Fatalf("agent = %+v", ag)
	}
}

func TestProfileDoesNotOverrideExplicit(t *testing.T) {
	ag, err := New(Options{
		Model:        simpleModel{},
		SystemPrompt: "explicit",
		MaxSteps:     2,
		Profile:      &Profile{SystemPrompt: "profile", MaxSteps: 5},
	})
	if err != nil {
		t.Fatal(err)
	}
	if ag.SystemPrompt != "explicit" || ag.MaxSteps != 2 {
		t.Fatalf("agent = %+v", ag)
	}
}

func TestModelMiddlewareOrder(t *testing.T) {
	var order []string
	mw := func(name string) ModelMiddleware {
		return func(next func(context.Context, model.Request) (model.Response, error)) func(context.Context, model.Request) (model.Response, error) {
			return func(ctx context.Context, req model.Request) (model.Response, error) {
				order = append(order, name)
				return next(ctx, req)
			}
		}
	}
	ag, err := New(Options{
		Model:           simpleModel{},
		ModelMiddleware: []ModelMiddleware{mw("outer"), mw("inner")},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	want := []string{"outer", "inner"}
	if len(order) != len(want) || order[0] != want[0] || order[1] != want[1] {
		t.Fatalf("order = %v", order)
	}
}

func TestMiddlewareSkipsTool(t *testing.T) {
	tools := tool.NewRegistry()
	echo := &echoTool{}
	tools.Register(echo)
	ag, err := New(Options{
		Model: &toolCallModel{name: "echo"},
		Tools: tools,
		Middleware: []Middleware{{
			BeforeTool: func(_ context.Context, call *ToolCall) error {
				call.Skip = true
				call.Result = "filtered"
				return nil
			},
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if echo.calls != 0 {
		t.Fatalf("tool calls = %d, want 0", echo.calls)
	}
}

func TestMiddlewareSkipsModel(t *testing.T) {
	m := &countingModel{}
	ag, err := New(Options{
		Model: m,
		Middleware: []Middleware{{
			BeforeModel: func(_ context.Context, call *ModelCall) error {
				call.Skip = true
				call.Response = &model.Response{Message: model.Message{
					Role: model.RoleAssistant, Content: "mocked",
				}}
				return nil
			},
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	result, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "mocked" || m.calls != 0 {
		t.Fatalf("output=%q model calls=%d", result.Output, m.calls)
	}
}

func TestMiddlewareNameReplaces(t *testing.T) {
	var order []string
	mw := func(label string) Middleware {
		return Middleware{
			Name: "shared",
			BeforeModel: func(context.Context, *ModelCall) error {
				order = append(order, label)
				return nil
			},
		}
	}
	ag, err := New(Options{Model: simpleModel{}, Middleware: []Middleware{mw("first"), mw("second")}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if len(order) != 1 || order[0] != "second" {
		t.Fatalf("order = %v", order)
	}
}

type countingModel struct{ calls int }

func (m *countingModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "model"}}, nil
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
