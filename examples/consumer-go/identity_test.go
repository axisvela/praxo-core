package main

import (
	"context"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type principal struct {
	ID       string
	TenantID string
	Role     string
	Expires  time.Time
}

type principalKey struct{}

func withPrincipal(ctx context.Context, p principal) context.Context {
	return context.WithValue(ctx, principalKey{}, p)
}

type identityModel struct {
	target string
	tenant string
}

func (m identityModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	last := req.Messages[len(req.Messages)-1]
	if last.Role == model.RoleTool {
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "recorded"}}, nil
	}
	return model.Response{Message: model.Message{
		Role: model.RoleAssistant,
		ToolCalls: []model.ToolCall{{
			ID: "record-1", Name: "record",
			Arguments: map[string]any{
				"target": m.target,
				"tenant": m.tenant,
				"role":   "admin",
			},
		}},
	}}, nil
}

func identityPolicy() policy.Hook {
	return policy.FuncHook(func(ctx context.Context, action policy.Action) (policy.Decision, error) {
		if action.Kind == "model.generate" {
			return policy.Decision{Allowed: true}, nil
		}
		if action.Kind != "tool.invoke" {
			return policy.Decision{Reason: "unsupported action"}, nil
		}
		p, ok := ctx.Value(principalKey{}).(principal)
		if !ok || p.ID == "" || p.TenantID == "" {
			return policy.Decision{Reason: "trusted principal is missing"}, nil
		}
		if p.Expires.IsZero() || time.Now().After(p.Expires) {
			return policy.Decision{Reason: "trusted principal is expired"}, nil
		}
		if p.Role != "operator" {
			return policy.Decision{Reason: "role is not permitted"}, nil
		}
		tenant, _ := action.Arguments["tenant"].(string)
		if tenant != p.TenantID {
			return policy.Decision{Reason: "tenant does not match the principal"}, nil
		}
		target, _ := action.Arguments["target"].(string)
		if action.ToolName != "record" || target != "public" {
			return policy.Decision{Reason: "operation is not permitted"}, nil
		}
		return policy.Decision{Allowed: true}, nil
	})
}

func runIdentity(ctx context.Context, target, tenant string) (int, error) {
	impl := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(impl)
	ag, err := agent.New(agent.Options{
		Model: identityModel{target: target, tenant: tenant}, Tools: tools, MaxSteps: 3,
		AllowedTools: []string{"record"}, Policy: identityPolicy(),
	})
	if err != nil {
		return impl.calls, err
	}
	_, err = ag.Run(ctx, agent.Session{ID: "identity-recipe"}, "record")
	return impl.calls, err
}

func TestIdentityRejectsMissingPrincipal(t *testing.T) {
	calls, err := runIdentity(context.Background(), "public", "acme")
	if err == nil || calls != 0 {
		t.Fatalf("effects=%d error=%v", calls, err)
	}
}

func TestIdentityRejectsExpiredPrincipal(t *testing.T) {
	ctx := withPrincipal(context.Background(), principal{
		ID: "actor-1", TenantID: "acme", Role: "operator",
		Expires: time.Now().Add(-time.Minute),
	})
	calls, err := runIdentity(ctx, "public", "acme")
	if err == nil || calls != 0 {
		t.Fatalf("effects=%d error=%v", calls, err)
	}
}

func TestIdentityRejectsTenantMismatch(t *testing.T) {
	ctx := withPrincipal(context.Background(), principal{
		ID: "actor-1", TenantID: "acme", Role: "operator",
		Expires: time.Now().Add(time.Hour),
	})
	calls, err := runIdentity(ctx, "public", "other")
	if err == nil || calls != 0 {
		t.Fatalf("effects=%d error=%v", calls, err)
	}
}

func TestIdentityIgnoresModelRoleClaim(t *testing.T) {
	ctx := withPrincipal(context.Background(), principal{
		ID: "actor-1", TenantID: "acme", Role: "viewer",
		Expires: time.Now().Add(time.Hour),
	})
	calls, err := runIdentity(ctx, "public", "acme")
	if err == nil || calls != 0 {
		t.Fatalf("effects=%d error=%v", calls, err)
	}
}

func TestIdentityAllowsVerifiedOperator(t *testing.T) {
	ctx := withPrincipal(context.Background(), principal{
		ID: "actor-1", TenantID: "acme", Role: "operator",
		Expires: time.Now().Add(time.Hour),
	})
	calls, err := runIdentity(ctx, "public", "acme")
	if err != nil || calls != 1 {
		t.Fatalf("effects=%d error=%v", calls, err)
	}
}
