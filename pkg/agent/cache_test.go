package agent

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func TestAgentPromptCacheHint(t *testing.T) {
	m := &requestModel{}
	ag := &Agent{
		Model: m,
		PromptCache: func(messages []model.Message) *model.CacheHint {
			return &model.CacheHint{StablePrefix: 1, TTL: "5m"}
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "hi"); err != nil {
		t.Fatal(err)
	}
	if m.req.CacheHint == nil || m.req.CacheHint.StablePrefix != 1 || m.req.CacheHint.TTL != "5m" {
		t.Fatalf("cache hint = %+v", m.req.CacheHint)
	}
}

func TestAgentPromptCacheAbsent(t *testing.T) {
	m := &requestModel{}
	ag := &Agent{Model: m}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "hi"); err != nil {
		t.Fatal(err)
	}
	if m.req.CacheHint != nil {
		t.Fatalf("cache hint = %+v, want nil", m.req.CacheHint)
	}
}
