package middleware

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/pkg/model"
)

type stubModel struct {
	response model.Response
	err      error
	calls    int
}

func (s *stubModel) Generate(context.Context, model.Request) (model.Response, error) {
	s.calls++
	return s.response, s.err
}

func TestFallbackModelUsesFallbackOnError(t *testing.T) {
	primary := &stubModel{err: errors.New("primary down")}
	fallback := &stubModel{response: model.Response{Message: model.Message{Content: "from fallback"}}}
	next := func(context.Context, model.Request) (model.Response, error) {
		return primary.Generate(context.Background(), model.Request{})
	}
	wrapped := FallbackModel(fallback)(next)
	resp, err := wrapped(context.Background(), model.Request{})
	if err != nil {
		t.Fatal(err)
	}
	if resp.Message.Content != "from fallback" || fallback.calls != 1 {
		t.Fatalf("resp=%+v fallbackCalls=%d", resp, fallback.calls)
	}
}

func TestFallbackModelKeepsPrimarySuccess(t *testing.T) {
	fallback := &stubModel{err: errors.New("fallback should not run")}
	next := func(context.Context, model.Request) (model.Response, error) {
		return model.Response{Message: model.Message{Content: "primary"}}, nil
	}
	resp, err := FallbackModel(fallback)(next)(context.Background(), model.Request{})
	if err != nil {
		t.Fatal(err)
	}
	if resp.Message.Content != "primary" || fallback.calls != 0 {
		t.Fatalf("resp=%+v fallbackCalls=%d", resp, fallback.calls)
	}
}

func TestFallbackModelReturnsFallbackError(t *testing.T) {
	primaryErr := errors.New("primary")
	fallbackErr := errors.New("fallback")
	next := func(context.Context, model.Request) (model.Response, error) { return model.Response{}, primaryErr }
	_, err := FallbackModel(&stubModel{err: fallbackErr})(next)(context.Background(), model.Request{})
	if !errors.Is(err, fallbackErr) {
		t.Fatalf("err = %v, want fallback error", err)
	}
}
