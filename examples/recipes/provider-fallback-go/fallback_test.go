package provider_fallback_recipe

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

var errPrimary = errors.New("primary unavailable")

type fakeModel struct {
	content string
	err     error
	calls   int
	cancel  context.CancelFunc
}

func (m *fakeModel) Generate(ctx context.Context, _ model.Request) (model.Response, error) {
	m.calls++
	if m.cancel != nil {
		m.cancel()
	}
	if m.err != nil {
		return model.Response{}, m.err
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: m.content}}, nil
}

// FallbackModel tries the primary model and optionally falls back to a
// secondary model. It never falls back after the caller cancels the context.
type FallbackModel struct {
	Primary       model.Model
	Secondary     model.Model
	ShouldFallback func(error) bool
}

func (m FallbackModel) Generate(ctx context.Context, request model.Request) (model.Response, error) {
	if m.Primary == nil {
		return m.Secondary.Generate(ctx, request)
	}
	response, err := m.Primary.Generate(ctx, request)
	if err == nil {
		return response, nil
	}
	if ctxErr := ctx.Err(); ctxErr != nil {
		return model.Response{}, ctxErr
	}
	if m.Secondary == nil {
		return model.Response{}, err
	}
	if m.ShouldFallback != nil && !m.ShouldFallback(err) {
		return model.Response{}, err
	}
	return m.Secondary.Generate(ctx, request)
}

func TestPrimarySuccessDoesNotFallBack(t *testing.T) {
	primary := &fakeModel{content: "primary"}
	secondary := &fakeModel{content: "secondary"}
	wrapper := FallbackModel{Primary: primary, Secondary: secondary}
	response, err := wrapper.Generate(context.Background(), model.Request{})
	if err != nil {
		t.Fatal(err)
	}
	if response.Message.Content != "primary" || secondary.calls != 0 {
		t.Fatalf("response=%#v secondary calls=%d", response, secondary.calls)
	}
}

func TestPrimaryFailureFallsBack(t *testing.T) {
	primary := &fakeModel{err: errPrimary}
	secondary := &fakeModel{content: "secondary"}
	wrapper := FallbackModel{Primary: primary, Secondary: secondary}
	response, err := wrapper.Generate(context.Background(), model.Request{})
	if err != nil {
		t.Fatal(err)
	}
	if response.Message.Content != "secondary" || secondary.calls != 1 {
		t.Fatalf("response=%#v secondary calls=%d", response, secondary.calls)
	}
}

func TestPredicateBlocksFallback(t *testing.T) {
	primary := &fakeModel{err: errPrimary}
	secondary := &fakeModel{content: "secondary"}
	wrapper := FallbackModel{
		Primary:        primary,
		Secondary:      secondary,
		ShouldFallback: func(error) bool { return false },
	}
	if _, err := wrapper.Generate(context.Background(), model.Request{}); !errors.Is(err, errPrimary) {
		t.Fatalf("err = %v, want primary error", err)
	}
	if secondary.calls != 0 {
		t.Fatalf("secondary calls = %d, want 0", secondary.calls)
	}
}

func TestBothFailReturnsFallbackError(t *testing.T) {
	primary := &fakeModel{err: errPrimary}
	secondaryErr := errors.New("secondary unavailable")
	secondary := &fakeModel{err: secondaryErr}
	wrapper := FallbackModel{Primary: primary, Secondary: secondary}
	if _, err := wrapper.Generate(context.Background(), model.Request{}); !errors.Is(err, secondaryErr) {
		t.Fatalf("err = %v, want the fallback error", err)
	}
}

func TestCancellationDoesNotFallBack(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	primary := &fakeModel{err: errPrimary, cancel: cancel}
	secondary := &fakeModel{content: "secondary"}
	wrapper := FallbackModel{Primary: primary, Secondary: secondary}
	if _, err := wrapper.Generate(ctx, model.Request{}); !errors.Is(err, context.Canceled) {
		t.Fatalf("err = %v, want context.Canceled", err)
	}
	if secondary.calls != 0 {
		t.Fatalf("secondary calls = %d, want 0", secondary.calls)
	}
}

func TestNilPrimaryUsesSecondary(t *testing.T) {
	secondary := &fakeModel{content: "secondary"}
	wrapper := FallbackModel{Secondary: secondary}
	response, err := wrapper.Generate(context.Background(), model.Request{})
	if err != nil {
		t.Fatal(err)
	}
	if response.Message.Content != "secondary" {
		t.Fatalf("response = %#v", response)
	}
}
