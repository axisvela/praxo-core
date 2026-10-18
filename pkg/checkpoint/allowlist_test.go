package checkpoint

import (
	"errors"
	"testing"
)

type allowlistedPayload struct {
	Value string `json:"value"`
}

func TestAllowlistRoundTrip(t *testing.T) {
	allow := NewAllowlist()
	if err := allow.Register("payload", func() any { return &allowlistedPayload{} }); err != nil {
		t.Fatal(err)
	}
	raw, err := allow.Marshal("payload", allowlistedPayload{Value: "ok"})
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := allow.Unmarshal(raw)
	if err != nil {
		t.Fatal(err)
	}
	payload, ok := decoded.(*allowlistedPayload)
	if !ok || payload.Value != "ok" {
		t.Fatalf("decoded = %#v", decoded)
	}
}

func TestAllowlistRejectsUnknownType(t *testing.T) {
	allow := NewAllowlist()
	raw := []byte(`{"type":"unknown","data":{"value":"x"}}`)
	if _, err := allow.Unmarshal(raw); !errors.Is(err, ErrTypeNotAllowed) {
		t.Fatalf("err = %v, want ErrTypeNotAllowed", err)
	}
}

func TestAllowlistRejectsUnregisteredMarshal(t *testing.T) {
	allow := NewAllowlist()
	if _, err := allow.Marshal("unknown", allowlistedPayload{}); !errors.Is(err, ErrTypeNotAllowed) {
		t.Fatalf("err = %v, want ErrTypeNotAllowed", err)
	}
}

func TestAllowlistRejectsMalformedEnvelope(t *testing.T) {
	allow := NewAllowlist()
	if err := allow.Register("payload", func() any { return &allowlistedPayload{} }); err != nil {
		t.Fatal(err)
	}
	if _, err := allow.Unmarshal([]byte(`{"type":"payload"`)); err == nil {
		t.Fatal("expected malformed envelope error")
	}
}

func TestAllowlistRejectsBadFactory(t *testing.T) {
	allow := NewAllowlist()
	if err := allow.Register("payload", func() any { return nil }); err != nil {
		t.Fatal(err)
	}
	if _, err := allow.Unmarshal([]byte(`{"type":"payload","data":{}}`)); err == nil {
		t.Fatal("expected nil factory error")
	}
}
