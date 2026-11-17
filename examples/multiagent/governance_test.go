package main

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"sync"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

var errBudgetExhausted = errors.New("delegation budget exhausted")

type sharedBudget struct {
	mu        sync.Mutex
	remaining int
}

func (b *sharedBudget) available() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.remaining > 0
}

func (b *sharedBudget) take() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.remaining <= 0 {
		return false
	}
	b.remaining--
	return true
}

type authority struct {
	allowed     map[string]bool
	delegable   map[string]bool
	maxDepth    int
	maxChildren int
	depth       int
	budget      *sharedBudget
	policy      policy.Hook
}

type childRequest struct {
	allowed   []string
	delegable []string
	policy    policy.Hook
}

type childScope struct {
	authority
	release func()
}

type governor struct {
	authority
	mu     sync.Mutex
	active int
}

func newGovernor(a authority) *governor {
	if a.budget == nil {
		a.budget = &sharedBudget{remaining: 1}
	}
	if a.maxChildren < 1 {
		a.maxChildren = 1
	}
	return &governor{authority: a}
}

func narrow(parent map[string]bool, requested []string) (map[string]bool, error) {
	out := make(map[string]bool, len(requested))
	for _, name := range requested {
		if !parent[name] {
			return nil, fmt.Errorf("delegation scope exceeds parent: %s", name)
		}
		out[name] = true
	}
	return out, nil
}

func (g *governor) delegate(req childRequest) (*childScope, error) {
	depth := g.depth + 1
	if depth > g.maxDepth {
		return nil, errors.New("delegation depth exceeded")
	}
	if len(req.allowed) == 0 {
		return nil, errors.New("delegation tool scope is empty")
	}
	allowed, err := narrow(g.delegable, req.allowed)
	if err != nil {
		return nil, err
	}
	allowed, err = narrow(g.allowed, keys(allowed))
	if err != nil {
		return nil, err
	}
	delegable, err := narrow(g.delegable, req.delegable)
	if err != nil {
		return nil, err
	}
	if !g.budget.available() {
		return nil, errBudgetExhausted
	}
	g.mu.Lock()
	if g.active >= g.maxChildren {
		g.mu.Unlock()
		return nil, errors.New("delegation child limit exceeded")
	}
	g.active++
	g.mu.Unlock()
	release := func() {
		g.mu.Lock()
		g.active--
		g.mu.Unlock()
	}
	return &childScope{
		authority: authority{
			allowed:     allowed,
			delegable:   delegable,
			maxDepth:    g.maxDepth,
			maxChildren: g.maxChildren,
			depth:       depth,
			budget:      g.budget,
			policy:      policyChain{g.policy, req.policy},
		},
		release: release,
	}, nil
}

type policyChain []policy.Hook

func (p policyChain) Authorize(ctx context.Context, action policy.Action) (policy.Decision, error) {
	for _, hook := range p {
		if hook == nil {
			continue
		}
		decision, err := hook.Authorize(ctx, action)
		if err != nil {
			return decision, err
		}
		if !decision.Allowed {
			return decision, nil
		}
	}
	return policy.Decision{Allowed: true}, nil
}

type budgetedTool struct {
	tool.Tool
	budget *sharedBudget
}

func (t budgetedTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	if !t.budget.take() {
		return nil, errBudgetExhausted
	}
	return t.Tool.Invoke(ctx, args)
}

func (c *childScope) run(ctx context.Context, m model.Model, tools *tool.Registry, prompt string, configure ...func(*agent.Options)) (*agent.Result, error) {
	names := keys(c.allowed)
	scoped := tool.NewRegistry()
	for _, name := range names {
		item, err := tools.Get(name)
		if err != nil {
			return nil, err
		}
		scoped.Register(budgetedTool{Tool: item, budget: c.budget})
	}
	opts := agent.Options{
		Model:            m,
		Tools:            scoped,
		MaxSteps:         3,
		AllowedTools:     names,
		Policy:           c.policy,
		RequirePolicy:    true,
		RequireToolScope: true,
	}
	for _, apply := range configure {
		apply(&opts)
	}
	ag, err := agent.New(opts)
	if err != nil {
		return nil, err
	}
	return ag.Run(ctx, agent.Session{ID: "governed-delegation"}, prompt)
}

type recordTool struct {
	calls int
}

func (t *recordTool) Name() string        { return "record" }
func (t *recordTool) Description() string { return "record a delegated effect" }
func (t *recordTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls++
	return "recorded", nil
}

type parentOnlyTool struct {
	calls int
}

func (t *parentOnlyTool) Name() string        { return "parent_only" }
func (t *parentOnlyTool) Description() string { return "parent-only capability" }
func (t *parentOnlyTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls++
	return "parent-effect", nil
}

type slowTool struct {
	started chan struct{}
	calls   int
}

func (t *slowTool) Name() string        { return "slow" }
func (t *slowTool) Description() string { return "wait for cancellation" }
func (t *slowTool) Invoke(ctx context.Context, _ map[string]any) (any, error) {
	close(t.started)
	<-ctx.Done()
	return nil, ctx.Err()
}

type scriptedModel struct {
	toolName  string
	arguments map[string]any
	final     string
	calls     int
}

func (m *scriptedModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{ToolCalls: []model.ToolCall{{
			ID:        "call-1",
			Name:      m.toolName,
			Arguments: m.arguments,
		}}}}, nil
	}
	return model.Response{Message: model.Message{Content: m.final}}, nil
}

func allowAll(context.Context, policy.Action) (policy.Decision, error) {
	return policy.Decision{Allowed: true}, nil
}

func recordPolicy(_ context.Context, action policy.Action) (policy.Decision, error) {
	if action.Kind != "tool.invoke" {
		return policy.Decision{Allowed: true}, nil
	}
	if action.ToolName != "record" {
		return policy.Decision{Allowed: false, Reason: "child may only record"}, nil
	}
	if action.Arguments["target"] == "blocked" {
		return policy.Decision{Allowed: false, Reason: "blocked target"}, nil
	}
	return policy.Decision{Allowed: true}, nil
}

func keys(set map[string]bool) []string {
	out := make([]string, 0, len(set))
	for key := range set {
		out = append(out, key)
	}
	sort.Strings(out)
	return out
}

func TestGovernedDelegationRejectsScopeEscalation(t *testing.T) {
	record := &recordTool{}
	parentOnly := &parentOnlyTool{}
	tools := tool.NewRegistry()
	tools.Register(record)
	tools.Register(parentOnly)
	g := newGovernor(authority{
		allowed:     map[string]bool{"record": true, "parent_only": true},
		delegable:   map[string]bool{"record": true},
		maxDepth:    1,
		maxChildren: 2,
		budget:      &sharedBudget{remaining: 2},
		policy:      policy.FuncHook(allowAll),
	})
	if _, err := g.delegate(childRequest{allowed: []string{"parent_only"}}); err == nil {
		t.Fatal("child scope escaped the delegable parent scope")
	}
	child, err := g.delegate(childRequest{allowed: []string{"record"}, policy: policy.FuncHook(recordPolicy)})
	if err != nil {
		t.Fatal(err)
	}
	defer child.release()
	if record.calls != 0 || parentOnly.calls != 0 {
		t.Fatalf("scope rejection produced effects: record=%d parent_only=%d", record.calls, parentOnly.calls)
	}
}

func TestGovernedDelegationRejectsExcessDepth(t *testing.T) {
	g := newGovernor(authority{
		allowed:     map[string]bool{"record": true},
		delegable:   map[string]bool{"record": true},
		maxDepth:    1,
		maxChildren: 1,
		budget:      &sharedBudget{remaining: 2},
		policy:      policy.FuncHook(allowAll),
	})
	child, err := g.delegate(childRequest{allowed: []string{"record"}})
	if err != nil {
		t.Fatal(err)
	}
	defer child.release()
	child.delegable = map[string]bool{"record": true}
	grand := newGovernor(child.authority)
	if _, err := grand.delegate(childRequest{allowed: []string{"record"}}); err == nil {
		t.Fatal("delegation exceeded the depth limit")
	}
}

func TestGovernedDelegationRejectsExcessChildren(t *testing.T) {
	g := newGovernor(authority{
		allowed:     map[string]bool{"record": true},
		delegable:   map[string]bool{"record": true},
		maxDepth:    1,
		maxChildren: 1,
		budget:      &sharedBudget{remaining: 2},
		policy:      policy.FuncHook(allowAll),
	})
	first, err := g.delegate(childRequest{allowed: []string{"record"}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := g.delegate(childRequest{allowed: []string{"record"}}); err == nil {
		t.Fatal("delegation exceeded the child limit")
	}
	first.release()
	second, err := g.delegate(childRequest{allowed: []string{"record"}})
	if err != nil {
		t.Fatalf("child slot was not released: %v", err)
	}
	second.release()
}

func TestGovernedDelegationSharesSiblingBudget(t *testing.T) {
	record := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(record)
	g := newGovernor(authority{
		allowed:     map[string]bool{"record": true},
		delegable:   map[string]bool{"record": true},
		maxDepth:    1,
		maxChildren: 2,
		budget:      &sharedBudget{remaining: 1},
		policy:      policy.FuncHook(allowAll),
	})
	first, err := g.delegate(childRequest{allowed: []string{"record"}, policy: policy.FuncHook(recordPolicy)})
	if err != nil {
		t.Fatal(err)
	}
	defer first.release()
	second, err := g.delegate(childRequest{allowed: []string{"record"}, policy: policy.FuncHook(recordPolicy)})
	if err != nil {
		t.Fatal(err)
	}
	defer second.release()
	if _, err := first.run(context.Background(), &scriptedModel{toolName: "record", arguments: map[string]any{"target": "first"}, final: "first-done"}, tools, "record once"); err != nil {
		t.Fatal(err)
	}
	if _, err := second.run(context.Background(), &scriptedModel{toolName: "record", arguments: map[string]any{"target": "second"}, final: "second-done"}, tools, "record twice"); !errors.Is(err, errBudgetExhausted) {
		t.Fatalf("expected shared budget denial, got %v", err)
	}
	if record.calls != 1 {
		t.Fatalf("sibling budget produced %d effects, want 1", record.calls)
	}
}

func TestGovernedDelegationCancelsChildWithoutEffects(t *testing.T) {
	slow := &slowTool{started: make(chan struct{})}
	tools := tool.NewRegistry()
	tools.Register(slow)
	g := newGovernor(authority{
		allowed:     map[string]bool{"slow": true},
		delegable:   map[string]bool{"slow": true},
		maxDepth:    1,
		maxChildren: 1,
		budget:      &sharedBudget{remaining: 1},
		policy:      policy.FuncHook(allowAll),
	})
	child, err := g.delegate(childRequest{allowed: []string{"slow"}})
	if err != nil {
		t.Fatal(err)
	}
	defer child.release()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() {
		_, err := child.run(ctx, &scriptedModel{toolName: "slow", arguments: map[string]any{}, final: "slow-done"}, tools, "wait")
		done <- err
	}()
	<-slow.started
	cancel()
	if err := <-done; err == nil {
		t.Fatal("canceled child reported success")
	}
	if slow.calls != 0 {
		t.Fatalf("canceled child produced %d effects", slow.calls)
	}
}

func TestGovernedDelegationReauthorizesFinalArguments(t *testing.T) {
	record := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(record)
	g := newGovernor(authority{
		allowed:     map[string]bool{"record": true},
		delegable:   map[string]bool{"record": true},
		maxDepth:    1,
		maxChildren: 1,
		budget:      &sharedBudget{remaining: 1},
		policy:      policy.FuncHook(allowAll),
	})
	child, err := g.delegate(childRequest{allowed: []string{"record"}, policy: policy.FuncHook(recordPolicy)})
	if err != nil {
		t.Fatal(err)
	}
	defer child.release()
	_, err = child.run(
		context.Background(),
		&scriptedModel{toolName: "record", arguments: map[string]any{"target": "safe"}, final: "unexpected"},
		tools,
		"record safely",
		func(opts *agent.Options) {
			opts.Hooks.OnToolCall = func(_ context.Context, _ string, call model.ToolCall) error {
				call.Arguments["target"] = "blocked"
				return nil
			}
		},
	)
	if err == nil {
		t.Fatal("edited child arguments were not reauthorized")
	}
	if record.calls != 0 {
		t.Fatalf("edited child arguments produced %d effects", record.calls)
	}
}
