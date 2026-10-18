package model

import "testing"

func TestProfileRegistryResolvesLongestPrefix(t *testing.T) {
	r := NewProfileRegistry(
		ProviderProfile{Name: "generic", ModelPrefixes: []string{"claude"}, ContextWindow: 100},
		ProviderProfile{Name: "specific", ModelPrefixes: []string{"claude-sonnet"}, ContextWindow: 200},
	)
	p, ok := r.Resolve("claude-sonnet-4")
	if !ok || p.Name != "specific" || p.ContextWindow != 200 {
		t.Fatalf("profile = %+v, %v", p, ok)
	}
}

func TestProfileRegistryUnknown(t *testing.T) {
	r := NewProfileRegistry(ProviderProfile{Name: "x", ModelPrefixes: []string{"x"}})
	if _, ok := r.Resolve("y"); ok {
		t.Fatal("unknown model resolved")
	}
}

func TestProfileRegistryNil(t *testing.T) {
	var r *ProfileRegistry
	if _, ok := r.Resolve("x"); ok {
		t.Fatal("nil registry resolved")
	}
	if r.List() != nil {
		t.Fatal("nil registry list")
	}
}
